#ifndef FSM_PATH_UTILS_H
#define FSM_PATH_UTILS_H

#include "strbuf.h"

struct alias_info
{
	struct strbuf alias;
	struct strbuf points_to;
};

struct fs_info {
	int is_remote;
	char *typename;
};

/*
 * Get some basic filesystem informtion for the given path
 *
 * Returns -1 on error, zero otherwise.
 */
int fsmonitor__get_fs_info(const char *path, struct fs_info *fs_info);

/*
 * Determines if the filesystem that path resides on is remote.
 *
 * Returns -1 on error, 0 if not remote, 1 if remote.
 */
int fsmonitor__is_fs_remote(const char *path);

/*
 * Get the alias in given path, if any.
 *
 * Sets alias to the first alias that matches any part of the path.
 *
 * Returns -1 on error, 0 otherwise.
 */
int fsmonitor__get_alias(const char *path, struct alias_info *info);

/*
 * Resolve the path against the given alias.
 *
 * Returns the resolved path if there is one, NULL otherwise.
 */
char *fsmonitor__resolve_alias(const char *path,
	const struct alias_info *info);


#endif
