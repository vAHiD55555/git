#include "cache.h"
#include "config.h"
#include "repository.h"
#include "fsmonitor-settings.h"
#include "fsmonitor-ipc.h"
#include "fsmonitor.h"
#include <sys/param.h>
#include <sys/mount.h>

/*
 * Check if monitoring remote working directories is allowed.
 *
 * By default, monitoring remote working directories is
 * disabled.  Users may override this behavior in enviroments where
 * they have proper support.
 */
static int check_config_allowremote(struct repository *r)
{
	int allow;

	if (!repo_config_get_bool(r, "fsmonitor.allowremote", &allow))
		return allow;

	return -1; /* fsmonitor.allowremote not set */
}

/*
 * [1] Remote working directories are problematic for FSMonitor.
 *
 * The underlying file system on the server machine and/or the remote
 * mount type (NFS, SAMBA, etc.) dictates whether notification events
 * are available at all to remote client machines.
 *
 * Kernel differences between the server and client machines also
 * dictate the how (buffering, frequency, de-dup) the events are
 * delivered to client machine processes.
 *
 * A client machine (such as a laptop) may choose to suspend/resume
 * and it is unclear (without lots of testing) whether the watcher can
 * resync after a resume.  We might be able to treat this as a normal
 * "events were dropped by the kernel" event and do our normal "flush
 * and resync" --or-- we might need to close the existing (zombie?)
 * notification fd and create a new one.
 *
 * In theory, the above issues need to be addressed whether we are
 * using the Hook or IPC API.
 *
 * So (for now at least), mark remote working directories as
 * incompatible by default.
 *
 * For the builtin FSMonitor, we create the Unix domain socket for the
 * IPC in the temporary directory.  If the temporary directory is
 * remote, then the socket will be created on the remote file system.
 * This can fail if the remote file system does not support UDS file
 * types (e.g. smbfs to a Windows server) or if the remote kernel does
 * not allow a non-local process to bind() the socket.
 *
 * Therefore remote UDS locations are marked as incompatible.
 *
 *
 * [2] FAT32 and NTFS working directories are problematic too.
 *
 * The builtin FSMonitor uses a Unix domain socket in the temporary
 * directory for IPC.  These Windows drive formats do not support
 * Unix domain sockets, so mark them as incompatible for the daemon.
 *
 */
static enum fsmonitor_reason check_volume(struct repository *r)
{
	struct statfs fs;

	if (statfs(r->worktree, &fs) == -1) {
		int saved_errno = errno;
		trace_printf_key(&trace_fsmonitor, "statfs('%s') failed: %s",
				 r->worktree, strerror(saved_errno));
		errno = saved_errno;
		return FSMONITOR_REASON_ERROR;
	}

	trace_printf_key(&trace_fsmonitor,
			 "statfs('%s') [type 0x%08x][flags 0x%08x] '%s'",
			 r->worktree, fs.f_type, fs.f_flags, fs.f_fstypename);

	if (!(fs.f_flags & MNT_LOCAL)) {
		switch (check_config_allowremote(r)) {
		case 0: /* config overrides and disables */
			return FSMONITOR_REASON_REMOTE;
		case 1: /* config overrides and enables */
			return FSMONITOR_REASON_OK;
		default:
			break; /* config has no opinion */
		}

		return FSMONITOR_REASON_REMOTE;
	}

	return FSMONITOR_REASON_OK;
}

static enum fsmonitor_reason check_uds_volume(void)
{
	struct statfs fs;
	const char *path = fsmonitor_ipc__get_path();

	if (statfs(path, &fs) == -1) {
		int saved_errno = errno;
		trace_printf_key(&trace_fsmonitor, "statfs('%s') failed: %s",
				 path, strerror(saved_errno));
		errno = saved_errno;
		return FSMONITOR_REASON_ERROR;
	}

	trace_printf_key(&trace_fsmonitor,
			 "statfs('%s') [type 0x%08x][flags 0x%08x] '%s'",
			 path, fs.f_type, fs.f_flags, fs.f_fstypename);

	if (!(fs.f_flags & MNT_LOCAL))
		return FSMONITOR_REASON_REMOTE;

	if (!strcmp(fs.f_fstypename, "msdos")) /* aka FAT32 */
		return FSMONITOR_REASON_NOSOCKETS;

	if (!strcmp(fs.f_fstypename, "ntfs"))
		return FSMONITOR_REASON_NOSOCKETS;

	return FSMONITOR_REASON_OK;
}

enum fsmonitor_reason fsm_os__incompatible(struct repository *r)
{
	enum fsmonitor_reason reason;

	reason = check_volume(r);
	if (reason != FSMONITOR_REASON_OK)
		return reason;

	reason = check_uds_volume();
	if (reason != FSMONITOR_REASON_OK)
		return reason;

	return FSMONITOR_REASON_OK;
}
