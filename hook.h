#include "config.h"
#include "list.h"
#include "strbuf.h"
#include "strvec.h"

struct hook
{
	struct list_head list;
	/*
	 * Config file which holds the hook.*.command definition.
	 * (This has nothing to do with the hookcmd.<name>.* configs.)
	 */
	enum config_scope origin;
	/* The literal command to run. */
	struct strbuf command;
	int from_hookdir;
};

/*
 * Provides a linked list of 'struct hook' detailing commands which should run
 * in response to the 'hookname' event, in execution order.
 */
struct list_head* hook_list(const struct strbuf *hookname);

enum hookdir_opt
{
	HOOKDIR_NO,
	HOOKDIR_WARN,
	HOOKDIR_INTERACTIVE,
	HOOKDIR_YES,
	HOOKDIR_UNKNOWN,
};

/*
 * Provides the hookdir_opt specified in the config without consulting any
 * command line arguments.
 */
enum hookdir_opt configured_hookdir_opt(void);

struct run_hooks_opt
{
	/* Environment vars to be set for each hook */
	struct strvec env;

	/* Args to be passed to each hook */
	struct strvec args;

	/*
	 * How should the hookdir be handled?
	 * Leave the RUN_HOOKS_OPT_INIT default in most cases; this only needs
	 * to be overridden if the user can override it at the command line.
	 */
	enum hookdir_opt run_hookdir;

	/* Path to file which should be piped to stdin for each hook */
	const char *path_to_stdin;
};

#define RUN_HOOKS_OPT_INIT  {   		\
	.env = STRVEC_INIT, 			\
	.args = STRVEC_INIT, 			\
	.path_to_stdin = NULL,			\
	.run_hookdir = configured_hookdir_opt()	\
}

void run_hooks_opt_init(struct run_hooks_opt *o);
void run_hooks_opt_clear(struct run_hooks_opt *o);

/*
 * Returns 1 if any hooks are specified in the config or if a hook exists in the
 * hookdir. Typically, invoke hook_exsts() like:
 *   hook_exists(hookname, configured_hookdir_opt());
 * Like with run_hooks, if you take a --run-hookdir flag, reflect that
 * user-specified behavior here instead.
 */
int hook_exists(const char *hookname, enum hookdir_opt should_run_hookdir);

/*
 * Runs all hooks associated to the 'hookname' event in order. Each hook will be
 * passed 'env' and 'args'. The file at 'stdin_path' will be closed and reopened
 * for each hook that runs.
 */
int run_hooks(const char *hookname, struct run_hooks_opt *options);

/* Free memory associated with a 'struct hook' */
void free_hook(struct hook *ptr);
/* Empties the list at 'head', calling 'free_hook()' on each entry */
void clear_hook_list(struct list_head *head);
