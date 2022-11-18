#include "builtin.h"
#include "parse-options.h"
#include "merge-strategies.h"
#include "run-command.h"

struct mofs_data {
	const char *program;
};

static void push_arg(struct strvec *oids, struct strvec *modes,
		     const struct object_id *oid, const unsigned int mode)
{
	if (oid) {
		strvec_push(oids, oid_to_hex(oid));
		strvec_pushf(modes, "%06o", mode);
	} else {
		strvec_push(oids, "");
		strvec_push(modes, "");
	}
}

static int merge_one_file(struct index_state *istate,
			  const struct object_id *orig_blob,
			  const struct object_id *our_blob,
			  const struct object_id *their_blob, const char *path,
			  unsigned int orig_mode, unsigned int our_mode,
			  unsigned int their_mode, void *data)
{
	struct mofs_data *d = data;
	const char *program = d->program;
	struct strvec oids = STRVEC_INIT;
	struct strvec modes = STRVEC_INIT;
	struct child_process cmd = CHILD_PROCESS_INIT;

	strvec_push(&cmd.args, program);

	push_arg(&oids, &modes, orig_blob, orig_mode);
	push_arg(&oids, &modes, our_blob, our_mode);
	push_arg(&oids, &modes, their_blob, their_mode);

	strvec_pushv(&cmd.args, oids.v);
	strvec_clear(&oids);

	strvec_push(&cmd.args, path);

	strvec_pushv(&cmd.args, modes.v);
	strvec_clear(&modes);

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
	struct option options[] = {
		OPT_BOOL('o', NULL, &one_shot,
			 N_("don't stop at the first failed merge")),
		OPT__QUIET(&quiet, N_("be quiet")),
		OPT_BOOL('a', NULL, &all,
			 N_("merge all files in the index that need merging")),
		OPT_END(),
	};
	struct mofs_data data = { 0 };

	/* Without this we cannot rely on waitpid() to tell
	 * what happened to our children.
	 */
	signal(SIGCHLD, SIG_DFL);

	argc = parse_options(argc, argv, prefix, options, usage, 0);
	if (!argc)
		usage_msg_opt(_("need a <merge-program> argument"), usage, options);
	data.program = argv[0];
	argv++;
	argc--;
	if (!argc && !all)
		usage_msg_opt(_("need '-a' or '<file>...'"),
			      usage, options);
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
