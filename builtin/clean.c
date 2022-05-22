/*
 * "git clean" builtin command
 *
 * Copyright (C) 2007 Shawn Bohrer
 *
 * Based on git-clean.sh by Pavel Roskin
 */

#define USE_THE_INDEX_COMPATIBILITY_MACROS
#include "builtin.h"
#include "cache.h"
#include "config.h"
#include "dir.h"
#include "parse-options.h"
#include "string-list.h"
#include "quote.h"
#include "column.h"
#include "color.h"
#include "pathspec.h"
#include "help.h"
#include "prompt.h"
#include "add-menu.h"

static int force = -1; /* unset */
static int interactive;
static struct string_list del_list = STRING_LIST_INIT_DUP;
static unsigned int colopts;

static const char *const builtin_clean_usage[] = {
	N_("git clean [-d] [-f] [-i] [-n] [-q] [-e <pattern>] [-x | -X] [--] <paths>..."),
	NULL
};

static const char *msg_remove = N_("Removing %s\n");
static const char *msg_would_remove = N_("Would remove %s\n");
static const char *msg_skip_git_dir = N_("Skipping repository %s\n");
static const char *msg_would_skip_git_dir = N_("Would skip repository %s\n");
static const char *msg_warn_remove_failed = N_("failed to remove %s");
static const char *msg_warn_lstat_failed = N_("could not lstat %s\n");
static const char *msg_skip_cwd = N_("Refusing to remove current working directory\n");
static const char *msg_would_skip_cwd = N_("Would refuse to remove current working directory\n");


static const char *color_interactive_slots[] = {
	[CLEAN_COLOR_ERROR]  = "error",
	[CLEAN_COLOR_HEADER] = "header",
	[CLEAN_COLOR_HELP]   = "help",
	[CLEAN_COLOR_PLAIN]  = "plain",
	[CLEAN_COLOR_PROMPT] = "prompt",
	[CLEAN_COLOR_RESET]  = "reset",
};

static int clean_use_color = -1;
static clean_color_settings clean_colors = {
	[CLEAN_COLOR_ERROR] = GIT_COLOR_BOLD_RED,
	[CLEAN_COLOR_HEADER] = GIT_COLOR_BOLD,
	[CLEAN_COLOR_HELP] = GIT_COLOR_BOLD_RED,
	[CLEAN_COLOR_PLAIN] = GIT_COLOR_NORMAL,
	[CLEAN_COLOR_PROMPT] = GIT_COLOR_BOLD_BLUE,
	[CLEAN_COLOR_RESET] = GIT_COLOR_RESET,
};

#define MENU_RETURN_NO_LOOP		10

define_list_config_array(color_interactive_slots);

static int git_clean_config(const char *var, const char *value, void *cb)
{
	const char *slot_name;

	if (starts_with(var, "column."))
		return git_column_config(var, value, "clean", &colopts);

	/* honors the color.interactive* config variables which also
	   applied in git-add--interactive and git-stash */
	if (!strcmp(var, "color.interactive")) {
		clean_use_color = git_config_colorbool(var, value);
		return 0;
	}
	if (skip_prefix(var, "color.interactive.", &slot_name)) {
		int slot = LOOKUP_CONFIG(color_interactive_slots, slot_name);
		if (slot < 0)
			return 0;
		if (!value)
			return config_error_nonbool(var);
		return color_parse(value, clean_colors[slot]);
	}

	if (!strcmp(var, "clean.requireforce")) {
		force = !git_config_bool(var, value);
		return 0;
	}

	/* inspect the color.ui config variable and others */
	return git_color_default_config(var, value, cb);
}

static int exclude_cb(const struct option *opt, const char *arg, int unset)
{
	struct string_list *exclude_list = opt->value;
	BUG_ON_OPT_NEG(unset);
	string_list_append(exclude_list, arg);
	return 0;
}

static int remove_dirs(struct strbuf *path, const char *prefix, int force_flag,
		int dry_run, int quiet, int *dir_gone)
{
	DIR *dir;
	struct strbuf quoted = STRBUF_INIT;
	struct strbuf realpath = STRBUF_INIT;
	struct strbuf real_ocwd = STRBUF_INIT;
	struct dirent *e;
	int res = 0, ret = 0, gone = 1, original_len = path->len, len;
	struct string_list dels = STRING_LIST_INIT_DUP;

	*dir_gone = 1;

	if ((force_flag & REMOVE_DIR_KEEP_NESTED_GIT) &&
	    is_nonbare_repository_dir(path)) {
		if (!quiet) {
			quote_path(path->buf, prefix, &quoted, 0);
			printf(dry_run ?  _(msg_would_skip_git_dir) : _(msg_skip_git_dir),
					quoted.buf);
		}

		*dir_gone = 0;
		goto out;
	}

	dir = opendir(path->buf);
	if (!dir) {
		/* an empty dir could be removed even if it is unreadble */
		res = dry_run ? 0 : rmdir(path->buf);
		if (res) {
			int saved_errno = errno;
			quote_path(path->buf, prefix, &quoted, 0);
			errno = saved_errno;
			warning_errno(_(msg_warn_remove_failed), quoted.buf);
			*dir_gone = 0;
		}
		ret = res;
		goto out;
	}

	strbuf_complete(path, '/');

	len = path->len;
	while ((e = readdir_skip_dot_and_dotdot(dir)) != NULL) {
		struct stat st;

		strbuf_setlen(path, len);
		strbuf_addstr(path, e->d_name);
		if (lstat(path->buf, &st))
			warning_errno(_(msg_warn_lstat_failed), path->buf);
		else if (S_ISDIR(st.st_mode)) {
			if (remove_dirs(path, prefix, force_flag, dry_run, quiet, &gone))
				ret = 1;
			if (gone) {
				quote_path(path->buf, prefix, &quoted, 0);
				string_list_append(&dels, quoted.buf);
			} else
				*dir_gone = 0;
			continue;
		} else {
			res = dry_run ? 0 : unlink(path->buf);
			if (!res) {
				quote_path(path->buf, prefix, &quoted, 0);
				string_list_append(&dels, quoted.buf);
			} else {
				int saved_errno = errno;
				quote_path(path->buf, prefix, &quoted, 0);
				errno = saved_errno;
				warning_errno(_(msg_warn_remove_failed), quoted.buf);
				*dir_gone = 0;
				ret = 1;
			}
			continue;
		}

		/* path too long, stat fails, or non-directory still exists */
		*dir_gone = 0;
		ret = 1;
		break;
	}
	closedir(dir);

	strbuf_setlen(path, original_len);

	if (*dir_gone) {
		/*
		 * Normalize path components in path->buf, e.g. change '\' to
		 * '/' on Windows.
		 */
		strbuf_realpath(&realpath, path->buf, 1);

		/*
		 * path and realpath are absolute; for comparison, we would
		 * like to transform startup_info->original_cwd to an absolute
		 * path too.
		 */
		 if (startup_info->original_cwd)
			 strbuf_realpath(&real_ocwd,
					 startup_info->original_cwd, 1);

		if (!strbuf_cmp(&realpath, &real_ocwd)) {
			printf("%s", dry_run ? _(msg_would_skip_cwd) : _(msg_skip_cwd));
			*dir_gone = 0;
		} else {
			res = dry_run ? 0 : rmdir(path->buf);
			if (!res)
				*dir_gone = 1;
			else {
				int saved_errno = errno;
				quote_path(path->buf, prefix, &quoted, 0);
				errno = saved_errno;
				warning_errno(_(msg_warn_remove_failed), quoted.buf);
				*dir_gone = 0;
				ret = 1;
			}
		}
	}

	if (!*dir_gone && !quiet) {
		int i;
		for (i = 0; i < dels.nr; i++)
			printf(dry_run ?  _(msg_would_remove) : _(msg_remove), dels.items[i].string);
	}
out:
	strbuf_release(&realpath);
	strbuf_release(&real_ocwd);
	strbuf_release(&quoted);
	string_list_clear(&dels, 0);
	return ret;
}

static void pretty_print_dels(void)
{
	struct string_list list = STRING_LIST_INIT_DUP;
	struct string_list_item *item;
	struct strbuf buf = STRBUF_INIT;
	const char *qname;
	struct column_options copts;

	for_each_string_list_item(item, &del_list) {
		qname = quote_path(item->string, NULL, &buf, 0);
		string_list_append(&list, qname);
	}

	/*
	 * always enable column display, we only consult column.*
	 * about layout strategy and stuff
	 */
	colopts = (colopts & ~COL_ENABLE_MASK) | COL_ENABLED;
	memset(&copts, 0, sizeof(copts));
	copts.indent = "  ";
	copts.padding = 2;
	print_columns(&list, colopts, &copts);
	strbuf_release(&buf);
	string_list_clear(&list, 0);
}

static void prompt_help_cmd(int singleton)
{
	clean_print_color(CLEAN_COLOR_HELP, &clean_colors, &clean_use_color);
	printf(singleton ?
		  _("Prompt help:\n"
		    "1          - select a numbered item\n"
		    "foo        - select item based on unique prefix\n"
		    "           - (empty) select nothing\n") :
		  _("Prompt help:\n"
		    "1          - select a single item\n"
		    "3-5        - select a range of items\n"
		    "2-3,6-9    - select multiple ranges\n"
		    "foo        - select item based on unique prefix\n"
		    "-...       - unselect specified items\n"
		    "*          - choose all items\n"
		    "           - (empty) finish selecting\n"));
	clean_print_color(CLEAN_COLOR_RESET, &clean_colors, &clean_use_color);
}

static int clean_cmd(void)
{
	return MENU_RETURN_NO_LOOP;
}

static int filter_by_patterns_cmd(void)
{
	struct dir_struct dir = DIR_INIT;
	struct strbuf confirm = STRBUF_INIT;
	struct strbuf **ignore_list;
	struct string_list_item *item;
	struct pattern_list *pl;
	int changed = -1, i;

	for (;;) {
		if (!del_list.nr)
			break;

		if (changed)
			pretty_print_dels();

		clean_print_color(CLEAN_COLOR_PROMPT, &clean_colors, &clean_use_color);
		printf(_("Input ignore patterns>> "));
		clean_print_color(CLEAN_COLOR_RESET, &clean_colors, &clean_use_color);
		if (git_read_line_interactively(&confirm) == EOF)
			putchar('\n');

		/* quit filter_by_pattern mode if press ENTER or Ctrl-D */
		if (!confirm.len)
			break;

		pl = add_pattern_list(&dir, EXC_CMDL, "manual exclude");
		ignore_list = strbuf_split_max(&confirm, ' ', 0);

		for (i = 0; ignore_list[i]; i++) {
			strbuf_trim(ignore_list[i]);
			if (!ignore_list[i]->len)
				continue;

			add_pattern(ignore_list[i]->buf, "", 0, pl, -(i+1));
		}

		changed = 0;
		for_each_string_list_item(item, &del_list) {
			int dtype = DT_UNKNOWN;

			if (is_excluded(&dir, &the_index, item->string, &dtype)) {
				*item->string = '\0';
				changed++;
			}
		}

		if (changed) {
			string_list_remove_empty_items(&del_list, 0);
		} else {
			clean_print_color(CLEAN_COLOR_ERROR, &clean_colors, &clean_use_color);
			printf_ln(_("WARNING: Cannot find items matched by: %s"), confirm.buf);
			clean_print_color(CLEAN_COLOR_RESET, &clean_colors, &clean_use_color);
		}

		strbuf_list_free(ignore_list);
		dir_clear(&dir);
	}

	strbuf_release(&confirm);
	return 0;
}

static int select_by_numbers_cmd(void)
{
	struct menu_opts menu_opts;
	struct menu_stuff menu_stuff;
	struct string_list_item *items;
	int *chosen;
	int i, j;

	menu_opts.header = NULL;
	menu_opts.prompt = N_("Select items to delete");
	menu_opts.flags = 0;

	menu_stuff.type = MENU_STUFF_TYPE_STRING_LIST;
	menu_stuff.stuff = &del_list;
	menu_stuff.nr = del_list.nr;

	chosen = list_and_choose(&menu_opts, &menu_stuff, &clean_colors, &clean_use_color, prompt_help_cmd);
	items = del_list.items;
	for (i = 0, j = 0; i < del_list.nr; i++) {
		if (i < chosen[j]) {
			*(items[i].string) = '\0';
		} else if (i == chosen[j]) {
			/* delete selected item */
			j++;
			continue;
		} else {
			/* end of chosen (chosen[j] == EOF), won't delete */
			*(items[i].string) = '\0';
		}
	}

	string_list_remove_empty_items(&del_list, 0);

	free(chosen);
	return 0;
}

static int ask_each_cmd(void)
{
	struct strbuf confirm = STRBUF_INIT;
	struct strbuf buf = STRBUF_INIT;
	struct string_list_item *item;
	const char *qname;
	int changed = 0, eof = 0;

	for_each_string_list_item(item, &del_list) {
		/* Ctrl-D should stop removing files */
		if (!eof) {
			qname = quote_path(item->string, NULL, &buf, 0);
			/* TRANSLATORS: Make sure to keep [y/N] as is */
			printf(_("Remove %s [y/N]? "), qname);
			if (git_read_line_interactively(&confirm) == EOF) {
				putchar('\n');
				eof = 1;
			}
		}
		if (!confirm.len || strncasecmp(confirm.buf, "yes", confirm.len)) {
			*item->string = '\0';
			changed++;
		}
	}

	if (changed)
		string_list_remove_empty_items(&del_list, 0);

	strbuf_release(&buf);
	strbuf_release(&confirm);
	return MENU_RETURN_NO_LOOP;
}

static int quit_cmd(void)
{
	string_list_clear(&del_list, 0);
	printf(_("Bye.\n"));
	return MENU_RETURN_NO_LOOP;
}

static int help_cmd(void)
{
	clean_print_color(CLEAN_COLOR_HELP, &clean_colors, &clean_use_color);
	printf_ln(_(
		    "clean               - start cleaning\n"
		    "filter by pattern   - exclude items from deletion\n"
		    "select by numbers   - select items to be deleted by numbers\n"
		    "ask each            - confirm each deletion (like \"rm -i\")\n"
		    "quit                - stop cleaning\n"
		    "help                - this screen\n"
		    "?                   - help for prompt selection"
		   ));
	clean_print_color(CLEAN_COLOR_RESET, &clean_colors, &clean_use_color);
	return 0;
}

static void interactive_main_loop(void)
{
	while (del_list.nr) {
		struct menu_opts menu_opts;
		struct menu_stuff menu_stuff;
		struct menu_item menus[] = {
			{'c', "clean",			0, clean_cmd},
			{'f', "filter by pattern",	0, filter_by_patterns_cmd},
			{'s', "select by numbers",	0, select_by_numbers_cmd},
			{'a', "ask each",		0, ask_each_cmd},
			{'q', "quit",			0, quit_cmd},
			{'h', "help",			0, help_cmd},
		};
		int *chosen;

		menu_opts.header = N_("*** Commands ***");
		menu_opts.prompt = N_("What now");
		menu_opts.flags = MENU_OPTS_SINGLETON;

		menu_stuff.type = MENU_STUFF_TYPE_MENU_ITEM;
		menu_stuff.stuff = menus;
		menu_stuff.nr = sizeof(menus) / sizeof(struct menu_item);

		clean_print_color(CLEAN_COLOR_HEADER, &clean_colors, &clean_use_color);
		printf_ln(Q_("Would remove the following item:",
			     "Would remove the following items:",
			     del_list.nr));
		clean_print_color(CLEAN_COLOR_RESET, &clean_colors, &clean_use_color);

		pretty_print_dels();

		chosen = list_and_choose(&menu_opts, &menu_stuff, &clean_colors, &clean_use_color, prompt_help_cmd);

		if (*chosen != EOF) {
			int ret;
			ret = menus[*chosen].fn();
			if (ret != MENU_RETURN_NO_LOOP) {
				FREE_AND_NULL(chosen);
				if (!del_list.nr) {
					clean_print_color(CLEAN_COLOR_ERROR, &clean_colors, &clean_use_color);
					printf_ln(_("No more files to clean, exiting."));
					clean_print_color(CLEAN_COLOR_RESET, &clean_colors, &clean_use_color);
					break;
				}
				continue;
			}
		} else {
			quit_cmd();
		}

		FREE_AND_NULL(chosen);
		break;
	}
}

static void correct_untracked_entries(struct dir_struct *dir)
{
	int src, dst, ign;

	for (src = dst = ign = 0; src < dir->nr; src++) {
		/* skip paths in ignored[] that cannot be inside entries[src] */
		while (ign < dir->ignored_nr &&
		       0 <= cmp_dir_entry(&dir->entries[src], &dir->ignored[ign]))
			ign++;

		if (ign < dir->ignored_nr &&
		    check_dir_entry_contains(dir->entries[src], dir->ignored[ign])) {
			/* entries[src] contains an ignored path, so we drop it */
			free(dir->entries[src]);
		} else {
			struct dir_entry *ent = dir->entries[src++];

			/* entries[src] does not contain an ignored path, so we keep it */
			dir->entries[dst++] = ent;

			/* then discard paths in entries[] contained inside entries[src] */
			while (src < dir->nr &&
			       check_dir_entry_contains(ent, dir->entries[src]))
				free(dir->entries[src++]);

			/* compensate for the outer loop's loop control */
			src--;
		}
	}
	dir->nr = dst;
}

int cmd_clean(int argc, const char **argv, const char *prefix)
{
	int i, res;
	int dry_run = 0, remove_directories = 0, quiet = 0, ignored = 0;
	int ignored_only = 0, config_set = 0, errors = 0, gone = 1;
	int rm_flags = REMOVE_DIR_KEEP_NESTED_GIT;
	struct strbuf abs_path = STRBUF_INIT;
	struct dir_struct dir = DIR_INIT;
	struct pathspec pathspec;
	struct strbuf buf = STRBUF_INIT;
	struct string_list exclude_list = STRING_LIST_INIT_NODUP;
	struct pattern_list *pl;
	struct string_list_item *item;
	const char *qname;
	struct option options[] = {
		OPT__QUIET(&quiet, N_("do not print names of files removed")),
		OPT__DRY_RUN(&dry_run, N_("dry run")),
		OPT__FORCE(&force, N_("force"), PARSE_OPT_NOCOMPLETE),
		OPT_BOOL('i', "interactive", &interactive, N_("interactive cleaning")),
		OPT_BOOL('d', NULL, &remove_directories,
				N_("remove whole directories")),
		OPT_CALLBACK_F('e', "exclude", &exclude_list, N_("pattern"),
		  N_("add <pattern> to ignore rules"), PARSE_OPT_NONEG, exclude_cb),
		OPT_BOOL('x', NULL, &ignored, N_("remove ignored files, too")),
		OPT_BOOL('X', NULL, &ignored_only,
				N_("remove only ignored files")),
		OPT_END()
	};

	git_config(git_clean_config, NULL);
	if (force < 0)
		force = 0;
	else
		config_set = 1;

	argc = parse_options(argc, argv, prefix, options, builtin_clean_usage,
			     0);

	if (!interactive && !dry_run && !force) {
		if (config_set)
			die(_("clean.requireForce set to true and neither -i, -n, nor -f given; "
				  "refusing to clean"));
		else
			die(_("clean.requireForce defaults to true and neither -i, -n, nor -f given;"
				  " refusing to clean"));
	}

	if (force > 1)
		rm_flags = 0;
	else
		dir.flags |= DIR_SKIP_NESTED_GIT;

	dir.flags |= DIR_SHOW_OTHER_DIRECTORIES;

	if (ignored && ignored_only)
		die(_("-x and -X cannot be used together"));
	if (!ignored)
		setup_standard_excludes(&dir);
	if (ignored_only)
		dir.flags |= DIR_SHOW_IGNORED;

	if (argc) {
		/*
		 * Remaining args implies pathspecs specified, and we should
		 * recurse within those.
		 */
		remove_directories = 1;
	}

	if (remove_directories && !ignored_only) {
		/*
		 * We need to know about ignored files too:
		 *
		 * If (ignored), then we will delete ignored files as well.
		 *
		 * If (!ignored), then even though we not are doing
		 * anything with ignored files, we need to know about them
		 * so that we can avoid deleting a directory of untracked
		 * files that also contains an ignored file within it.
		 *
		 * For the (!ignored) case, since we only need to avoid
		 * deleting ignored files, we can set
		 * DIR_SHOW_IGNORED_TOO_MODE_MATCHING in order to avoid
		 * recursing into a directory which is itself ignored.
		 */
		dir.flags |= DIR_SHOW_IGNORED_TOO;
		if (!ignored)
			dir.flags |= DIR_SHOW_IGNORED_TOO_MODE_MATCHING;

		/*
		 * Let the fill_directory() machinery know that we aren't
		 * just recursing to collect the ignored files; we want all
		 * the untracked ones so that we can delete them.  (Note:
		 * we could also set DIR_KEEP_UNTRACKED_CONTENTS when
		 * ignored_only is true, since DIR_KEEP_UNTRACKED_CONTENTS
		 * only has effect in combination with DIR_SHOW_IGNORED_TOO.  It makes
		 * the code clearer to exclude it, though.
		 */
		dir.flags |= DIR_KEEP_UNTRACKED_CONTENTS;
	}

	prepare_repo_settings(the_repository);
	the_repository->settings.command_requires_full_index = 0;

	if (read_cache() < 0)
		die(_("index file corrupt"));

	pl = add_pattern_list(&dir, EXC_CMDL, "--exclude option");
	for (i = 0; i < exclude_list.nr; i++)
		add_pattern(exclude_list.items[i].string, "", 0, pl, -(i+1));

	parse_pathspec(&pathspec, 0,
		       PATHSPEC_PREFER_CWD,
		       prefix, argv);

	fill_directory(&dir, &the_index, &pathspec);
	correct_untracked_entries(&dir);

	for (i = 0; i < dir.nr; i++) {
		struct dir_entry *ent = dir.entries[i];
		struct stat st;
		const char *rel;

		if (!cache_name_is_other(ent->name, ent->len))
			continue;

		if (lstat(ent->name, &st))
			die_errno("Cannot lstat '%s'", ent->name);

		if (S_ISDIR(st.st_mode) && !remove_directories)
			continue;

		rel = relative_path(ent->name, prefix, &buf);
		string_list_append(&del_list, rel);
	}

	dir_clear(&dir);

	if (interactive && del_list.nr > 0)
		interactive_main_loop();

	for_each_string_list_item(item, &del_list) {
		struct stat st;

		strbuf_reset(&abs_path);
		if (prefix)
			strbuf_addstr(&abs_path, prefix);

		strbuf_addstr(&abs_path, item->string);

		/*
		 * we might have removed this as part of earlier
		 * recursive directory removal, so lstat() here could
		 * fail with ENOENT.
		 */
		if (lstat(abs_path.buf, &st))
			continue;

		if (S_ISDIR(st.st_mode)) {
			if (remove_dirs(&abs_path, prefix, rm_flags, dry_run, quiet, &gone))
				errors++;
			if (gone && !quiet) {
				qname = quote_path(item->string, NULL, &buf, 0);
				printf(dry_run ? _(msg_would_remove) : _(msg_remove), qname);
			}
		} else {
			res = dry_run ? 0 : unlink(abs_path.buf);
			if (res) {
				int saved_errno = errno;
				qname = quote_path(item->string, NULL, &buf, 0);
				errno = saved_errno;
				warning_errno(_(msg_warn_remove_failed), qname);
				errors++;
			} else if (!quiet) {
				qname = quote_path(item->string, NULL, &buf, 0);
				printf(dry_run ? _(msg_would_remove) : _(msg_remove), qname);
			}
		}
	}

	strbuf_release(&abs_path);
	strbuf_release(&buf);
	string_list_clear(&del_list, 0);
	string_list_clear(&exclude_list, 0);
	return (errors != 0);
}
