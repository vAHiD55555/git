#include "fsmonitor.h"
#include "fsmonitor-path-utils.h"
#include <errno.h>
#include <mntent.h>
#include <sys/mount.h>
#include <sys/statvfs.h>

/*
 * https://github.com/coreutils/gnulib/blob/master/lib/mountlist.c
 */
#ifndef ME_REMOTE
/* A file system is "remote" if its Fs_name contains a ':'
   or if (it is of type (smbfs or cifs) and its Fs_name starts with '//')
   or if it is of any other of the listed types
   or Fs_name is equal to "-hosts" (used by autofs to mount remote fs).
   "VM" file systems like prl_fs or vboxsf are not considered remote here. */
# define ME_REMOTE(Fs_name, Fs_type)            \
	(strchr (Fs_name, ':') != NULL              \
	 || ((Fs_name)[0] == '/'                    \
		 && (Fs_name)[1] == '/'                 \
		 && (strcmp (Fs_type, "smbfs") == 0     \
			 || strcmp (Fs_type, "smb3") == 0   \
			 || strcmp (Fs_type, "cifs") == 0)) \
	 || strcmp (Fs_type, "acfs") == 0           \
	 || strcmp (Fs_type, "afs") == 0            \
	 || strcmp (Fs_type, "coda") == 0           \
	 || strcmp (Fs_type, "auristorfs") == 0     \
	 || strcmp (Fs_type, "fhgfs") == 0          \
	 || strcmp (Fs_type, "gpfs") == 0           \
	 || strcmp (Fs_type, "ibrix") == 0          \
	 || strcmp (Fs_type, "ocfs2") == 0          \
	 || strcmp (Fs_type, "vxfs") == 0           \
	 || strcmp ("-hosts", Fs_name) == 0)
#endif

static struct mntent *find_mount(const char *path, const struct statvfs *fs)
{
	const char *const mounts = "/proc/mounts";
	const char *rp = real_pathdup(path, 1);
	struct mntent *ment = NULL;
	struct mntent *found = NULL;
	struct statvfs mntfs;
	FILE *fp;
	int dlen, plen, flen = 0;

	fp = setmntent(mounts, "r");
	if (!fp) {
		error_errno(_("setmntent('%s') failed"), mounts);
		return NULL;
	}

	plen = strlen(rp);

	/* read all the mount information and compare to path */
	while ((ment = getmntent(fp)) != NULL) {
		if (statvfs(ment->mnt_dir, &mntfs)) {
			switch (errno) {
			case EPERM:
			case ESRCH:
			case EACCES:
				continue;
			default:
				error_errno(_("statvfs('%s') failed"), ment->mnt_dir);
				endmntent(fp);
				return NULL;
			}
		}

		/* is mount on the same filesystem and is a prefix of the path */
		if ((fs->f_fsid == mntfs.f_fsid) &&
			!strncmp(ment->mnt_dir, rp, strlen(ment->mnt_dir))) {
			dlen = strlen(ment->mnt_dir);
			if (dlen > plen)
				continue;
			/*
			 * root is always a potential match; otherwise look for
			 * directory prefix
			 */
			if ((dlen == 1 && ment->mnt_dir[0] == '/') ||
				(dlen > flen && (!rp[dlen] || rp[dlen] == '/'))) {
				flen = dlen;
				/*
				 * https://man7.org/linux/man-pages/man3/getmntent.3.html
				 *
				 * The pointer points to a static area of memory which is
				 * overwritten by subsequent calls to getmntent().
				 */
				if (!found)
					CALLOC_ARRAY(found, 1);
				free(found->mnt_dir);
				free(found->mnt_type);
				free(found->mnt_fsname);
				found->mnt_dir = xmemdupz(ment->mnt_dir, strlen(ment->mnt_dir));
				found->mnt_type = xmemdupz(ment->mnt_type, strlen(ment->mnt_type));
				found->mnt_fsname = xmemdupz(ment->mnt_fsname, strlen(ment->mnt_fsname));
			}
		}
	}
	endmntent(fp);

	return found;
}

int fsmonitor__get_fs_info(const char *path, struct fs_info *fs_info)
{
	struct mntent *ment;
	struct statvfs fs;

	if (statvfs(path, &fs))
		return error_errno(_("statvfs('%s') failed"), path);

	ment = find_mount(path, &fs);
	if (!ment)
		return -1;

	trace_printf_key(&trace_fsmonitor,
			 "statvfs('%s') [flags 0x%08lx] '%s' '%s'",
			 path, fs.f_flag, ment->mnt_type, ment->mnt_fsname);

	if (ME_REMOTE(ment->mnt_fsname, ment->mnt_type))
		fs_info->is_remote = 1;
	else
		fs_info->is_remote = 0;

	fs_info->typename = ment->mnt_fsname;
	free(ment->mnt_dir);
	free(ment->mnt_type);
	free(ment);

	trace_printf_key(&trace_fsmonitor,
				"'%s' is_remote: %d",
				path, fs_info->is_remote);
	return 0;
}

int fsmonitor__is_fs_remote(const char *path)
{
	struct fs_info fs;

	if (fsmonitor__get_fs_info(path, &fs))
		return -1;

	free(fs.typename);

	return fs.is_remote;
}

/*
 * No-op for now.
 */
int fsmonitor__get_alias(const char *path, struct alias_info *info)
{
	return 0;
}

/*
 * No-op for now.
 */
char *fsmonitor__resolve_alias(const char *path,
	const struct alias_info *info)
{
	return NULL;
}
