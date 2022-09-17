#include "fsmonitor.h"
#include "fsmonitor-path-utils.h"
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/param.h>
#include <sys/mount.h>

int fsmonitor__get_fs_info(const char *path, struct fs_info *fs_info)
{
	struct statfs fs;
	if (statfs(path, &fs) == -1) {
		int saved_errno = errno;
		trace_printf_key(&trace_fsmonitor, "statfs('%s') failed: %s",
				 path, strerror(saved_errno));
		errno = saved_errno;
		return -1;
	}

	trace_printf_key(&trace_fsmonitor,
			 "statfs('%s') [type 0x%08x][flags 0x%08x] '%s'",
			 path, fs.f_type, fs.f_flags, fs.f_fstypename);

	if (!(fs.f_flags & MNT_LOCAL))
		fs_info->is_remote = 1;
	else
		fs_info->is_remote = 0;

	fs_info->typename = fs.f_fstypename;

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
	return fs.is_remote;
}

/*
 * Scan the root directory for synthetic firmlinks that when resolved
 * are a prefix of the path, stopping at the first one found.
 *
 * Some information about firmlinks and synthetic firmlinks:
 * https://eclecticlight.co/2020/01/23/catalina-boot-volumes/
 *
 * macOS no longer allows symlinks in the root directory; any link found
 * there is therefore a synthetic firmlink.
 *
 * If this function gets called often, will want to cache all the firmlink
 * information, but for now there is only one caller of this function.
 *
 * If there is more than one alias for the path, that is another
 * matter altogether.
 */
int fsmonitor__get_alias(const char *path, struct alias_info *info)
{
	DIR *dir;
	int read;
	int retval = -1;
	struct dirent *de;
	struct strbuf alias;
	struct strbuf points_to;

	dir = opendir("/");
	if (!dir) {
		error_errno("opendir('/') failed");
		return -1;
	}

	strbuf_init(&alias, 256);

	/* no way of knowing what the link will resolve to, so MAXPATHLEN */
	strbuf_init(&points_to, MAXPATHLEN);

	while ((de = readdir(dir)) != NULL) {
		strbuf_reset(&alias);
		strbuf_addch(&alias, '/');
		strbuf_add(&alias, de->d_name, strlen(de->d_name));

		read = readlink(alias.buf, points_to.buf, MAXPATHLEN);
		if (read > 0) {
			strbuf_setlen(&points_to, read);
			if ((!strncmp(points_to.buf, path, points_to.len))
				&& path[points_to.len] == '/') {
				strbuf_addbuf(&info->alias, &alias);
				strbuf_addbuf(&info->points_to, &points_to);
				trace_printf_key(&trace_fsmonitor,
					"Found alias for '%s' : '%s' -> '%s'",
					path, info->alias.buf, info->points_to.buf);
				retval = 0;
				goto done;
			}
		} else if (!read) {
			BUG("readlink returned 0");
		} else if (errno != EINVAL) { /* Something other than not a link */
			error_errno("readlink('%s') failed", alias.buf);
			goto done;
		}
	}
	retval = 0; /* no alias */

done:
	if (closedir(dir) < 0)
		warning_errno("closedir('/') failed");
	strbuf_release(&alias);
	strbuf_release(&points_to);
	return retval;
}

char *fsmonitor__resolve_alias(const char *path,
	const struct alias_info *info)
{
	if (!info->alias.len)
		return NULL;

	if ((!strncmp(info->alias.buf, path, info->alias.len))
		&& path[info->alias.len] == '/') {
		struct strbuf tmp = STRBUF_INIT;
		const char *remainder = path + info->alias.len;

		strbuf_addbuf(&tmp, &info->points_to);
		strbuf_add(&tmp, remainder, strlen(remainder));
		return strbuf_detach(&tmp, NULL);
	}

	return NULL;
}
