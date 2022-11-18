#include "builtin.h"
#include "parse-options.h"
#include "merge-strategies.h"
#include "run-command.h"

struct mofs_data {
	const char *program;
};

static int merge_one_file(struct index_state *istate,
			  const struct object_id *orig_blob,
			  const struct object_id *our_blob,
			  const struct object_id *their_blob, const char *path,
			  unsigned int orig_mode, unsigned int our_mode,
			  unsigned int their_mode, void *data)
{
	struct mofs_data *d = data;
	const char *pgm = d->program;
	const char *arguments[] = { pgm, "", "", "", path, "", "", "", NULL };
	char hexbuf[4][GIT_MAX_HEXSZ + 1];
	char ownbuf[4][60];
	int stage = 0;
	struct child_process cmd = CHILD_PROCESS_INIT;

#define ADD_MOF_ARG(oid, mode) \
	if ((oid)) { \
		stage++; \
		oid_to_hex_r(hexbuf[stage], (oid)); \
		xsnprintf(ownbuf[stage], sizeof(ownbuf[stage]), "%06o", (mode)); \
		arguments[stage] = hexbuf[stage]; \
		arguments[stage + 4] = ownbuf[stage]; \
	}

	ADD_MOF_ARG(orig_blob, orig_mode);
	ADD_MOF_ARG(our_blob, our_mode);
	ADD_MOF_ARG(their_blob, their_mode);

	strvec_pushv(&cmd.args, arguments);
	return run_command(&cmd);
}

int cmd_merge_index(int argc, const char **argv, const char *prefix)
{
	int err = 0;
	int all = 0;
	int one_shot = 0;
	int quiet = 0;
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
	struct mofs_data data = { 0 };

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
	data.program = argv[0];
	argc = parse_options(argc, argv, prefix, options_prog, usage, 0);
	if (argc && all)
		usage_msg_opt(_("'-a' and '<file>...' are mutually exclusive"),
			      usage, options);

	repo_read_index(the_repository);

	/* TODO: audit for interaction with sparse-index. */
	ensure_full_index(the_repository->index);

	if (all)
		err |= merge_all_index(the_repository->index, one_shot, quiet,
				       merge_one_file, &data);
	else
		for (size_t i = 0; i < argc; i++)
			err |= merge_index_path(the_repository->index,
						one_shot, quiet, argv[i],
						merge_one_file, &data);

	return err;
}
