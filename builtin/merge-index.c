#include "builtin.h"
#include "parse-options.h"
#include "run-command.h"

static const char *pgm;
static int one_shot, quiet;
static int err;

static int merge_entry(struct index_state *istate, int pos, const char *path)
{
	int found;
	const char *arguments[] = { pgm, "", "", "", path, "", "", "", NULL };
	char hexbuf[4][GIT_MAX_HEXSZ + 1];
	char ownbuf[4][60];
	struct child_process cmd = CHILD_PROCESS_INIT;

	if (pos >= istate->cache_nr)
		die(_("'%s' is not in the cache"), path);
	found = 0;
	do {
		const struct cache_entry *ce = istate->cache[pos];
		int stage = ce_stage(ce);

		if (strcmp(ce->name, path))
			break;
		found++;
		oid_to_hex_r(hexbuf[stage], &ce->oid);
		xsnprintf(ownbuf[stage], sizeof(ownbuf[stage]), "%o", ce->ce_mode);
		arguments[stage] = hexbuf[stage];
		arguments[stage + 4] = ownbuf[stage];
	} while (++pos < istate->cache_nr);
	if (!found)
		die(_("'%s' is not in the cache"), path);

	strvec_pushv(&cmd.args, arguments);
	if (run_command(&cmd)) {
		if (one_shot)
			err++;
		else {
			if (!quiet)
				die(_("merge program failed"));
			exit(1);
		}
	}
	return found;
}

static void merge_one_path(struct index_state *istate, const char *path)
{
	int pos = index_name_pos(istate, path, strlen(path));

	/*
	 * If it already exists in the cache as stage0, it's
	 * already merged and there is nothing to do.
	 */
	if (pos < 0)
		merge_entry(istate, -pos-1, path);
}

static void merge_all(struct index_state *istate)
{
	int i;

	for (i = 0; i < istate->cache_nr; i++) {
		const struct cache_entry *ce = istate->cache[i];
		if (!ce_stage(ce))
			continue;
		i += merge_entry(istate, i, ce->name)-1;
	}
}

int cmd_merge_index(int argc, const char **argv, const char *prefix)
{
	int all = 0;
	const char * const usage[] = {
		N_("git merge-index [-o] [-q] <merge-program> (-a | ([--] <file>...))"),
		NULL
	};
#define OPT__MERGE_INDEX_ALL(v) \
	OPT_BOOL('a', NULL, (v), \
		 N_("merge all files in the index that need merging"))
	struct option options[] = {
		OPT_BOOL('o', NULL, &one_shot,
			 N_("don't stop at the first failed merge")),
		OPT__QUIET(&quiet, N_("be quiet")),
		OPT__MERGE_INDEX_ALL(&all), /* include "-a" to show it in "-bh" */
		OPT_END(),
	};
	struct option options_prog[] = {
		OPT__MERGE_INDEX_ALL(&all),
		OPT_END(),
	};
#undef OPT__MERGE_INDEX_ALL

	/* Without this we cannot rely on waitpid() to tell
	 * what happened to our children.
	 */
	signal(SIGCHLD, SIG_DFL);

	if (argc < 3)
		usage_with_options(usage, options);

	/* Option parsing without <merge-program> options */
	argc = parse_options(argc, argv, prefix, options, usage,
			     PARSE_OPT_STOP_AT_NON_OPTION);
	if (all)
		usage_msg_optf(_("'%s' option can only be provided after '<merge-program>'"),
			      usage, options, "-a");
	/* <merge-program> and its options */
	if (!argc)
		usage_msg_opt(_("need a <merge-program> argument"), usage, options);
	pgm = argv[0];
	argc = parse_options(argc, argv, prefix, options_prog, usage, 0);
	if (argc && all)
		usage_msg_opt(_("'-a' and '<file>...' are mutually exclusive"),
			      usage, options);

	repo_read_index(the_repository);

	/* TODO: audit for interaction with sparse-index. */
	ensure_full_index(the_repository->index);

	if (all)
		merge_all(the_repository->index);
	else
		for (size_t i = 0; i < argc; i++)
			merge_one_path(the_repository->index, argv[i]);

	if (err && !quiet)
		die(_("merge program failed"));
	return err;
}
