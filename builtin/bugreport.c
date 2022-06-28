#include "builtin.h"
#include "parse-options.h"
#include "strbuf.h"
#include "help.h"
#include "compat/compiler.h"
#include "hook.h"
#include "hook-list.h"
#include "dir.h"
#include "object-store.h"
#include "packfile.h"
#include "archive.h"


static void get_system_info(struct strbuf *sys_info)
{
	struct utsname uname_info;
	char *shell = NULL;

	/* get git version from native cmd */
	strbuf_addstr(sys_info, _("git version:\n"));
	get_version_info(sys_info, 1);

	/* system call for other version info */
	strbuf_addstr(sys_info, "uname: ");
	if (uname(&uname_info))
		strbuf_addf(sys_info, _("uname() failed with error '%s' (%d)\n"),
			    strerror(errno),
			    errno);
	else
		strbuf_addf(sys_info, "%s %s %s %s\n",
			    uname_info.sysname,
			    uname_info.release,
			    uname_info.version,
			    uname_info.machine);

	strbuf_addstr(sys_info, _("compiler info: "));
	get_compiler_info(sys_info);

	strbuf_addstr(sys_info, _("libc info: "));
	get_libc_info(sys_info);

	shell = getenv("SHELL");
	strbuf_addf(sys_info, "$SHELL (typically, interactive shell): %s\n",
		    shell ? shell : "<unset>");
}

static void get_populated_hooks(struct strbuf *hook_info, int nongit)
{
	const char **p;

	if (nongit) {
		strbuf_addstr(hook_info,
			_("not run from a git repository - no hooks to show\n"));
		return;
	}

	for (p = hook_name_list; *p; p++) {
		const char *hook = *p;

		if (hook_exists(hook))
			strbuf_addf(hook_info, "%s\n", hook);
	}
}

static const char * const bugreport_usage[] = {
	N_("git bugreport [<options>]"),
	NULL
};

static int get_bug_template(struct strbuf *template)
{
	const char template_text[] = N_(
"Thank you for filling out a Git bug report!\n"
"Please answer the following questions to help us understand your issue.\n"
"\n"
"What did you do before the bug happened? (Steps to reproduce your issue)\n"
"\n"
"What did you expect to happen? (Expected behavior)\n"
"\n"
"What happened instead? (Actual behavior)\n"
"\n"
"What's different between what you expected and what actually happened?\n"
"\n"
"Anything else you want to add:\n"
"\n"
"Please review the rest of the bug report below.\n"
"You can delete any lines you don't wish to share.\n");

	strbuf_addstr(template, _(template_text));
	return 0;
}

static void get_header(struct strbuf *buf, const char *title)
{
	strbuf_addf(buf, "\n\n[%s]\n", title);
}

static void dir_file_stats_objects(const char *full_path, size_t full_path_len,
				   const char *file_name, void *data)
{
	struct strbuf *buf = data;
	struct stat st;

	if (!stat(full_path, &st))
		strbuf_addf(buf, "%-70s %16" PRIuMAX "\n", file_name,
			    (uintmax_t)st.st_size);
}

static int dir_file_stats(struct object_directory *object_dir, void *data)
{
	struct strbuf *buf = data;

	strbuf_addf(buf, "Contents of %s:\n", object_dir->path);

	for_each_file_in_pack_dir(object_dir->path, dir_file_stats_objects,
				  data);

	return 0;
}

static int count_files(char *path)
{
	DIR *dir = opendir(path);
	struct dirent *e;
	int count = 0;

	if (!dir)
		return 0;

	while ((e = readdir(dir)) != NULL)
		if (!is_dot_or_dotdot(e->d_name) && e->d_type == DT_REG)
			count++;

	closedir(dir);
	return count;
}

static void loose_objs_stats(struct strbuf *buf, const char *path)
{
	DIR *dir = opendir(path);
	struct dirent *e;
	int count;
	int total = 0;
	unsigned char c;
	struct strbuf count_path = STRBUF_INIT;
	size_t base_path_len;

	if (!dir)
		return;

	strbuf_addstr(buf, "Object directory stats for ");
	strbuf_add_absolute_path(buf, path);
	strbuf_addstr(buf, ":\n");

	strbuf_add_absolute_path(&count_path, path);
	strbuf_addch(&count_path, '/');
	base_path_len = count_path.len;

	while ((e = readdir(dir)) != NULL)
		if (!is_dot_or_dotdot(e->d_name) &&
		    e->d_type == DT_DIR && strlen(e->d_name) == 2 &&
		    !hex_to_bytes(&c, e->d_name, 1)) {
			strbuf_setlen(&count_path, base_path_len);
			strbuf_addstr(&count_path, e->d_name);
			total += (count = count_files(count_path.buf));
			strbuf_addf(buf, "%s : %7d files\n", e->d_name, count);
		}

	strbuf_addf(buf, "Total: %d loose objects", total);

	strbuf_release(&count_path);
	closedir(dir);
}

static int add_directory_to_archiver(struct strvec *archiver_args,
				     const char *path, int recurse)
{
	int at_root = !*path;
	DIR *dir = opendir(at_root ? "." : path);
	struct dirent *e;
	struct strbuf buf = STRBUF_INIT;
	size_t len;
	int res = 0;

	if (!dir)
		return error_errno(_("could not open directory '%s'"), path);

	if (!at_root)
		strbuf_addf(&buf, "%s/", path);
	len = buf.len;
	strvec_pushf(archiver_args, "--prefix=%s", buf.buf);

	while (!res && (e = readdir(dir))) {
		if (!strcmp(".", e->d_name) || !strcmp("..", e->d_name))
			continue;

		strbuf_setlen(&buf, len);
		strbuf_addstr(&buf, e->d_name);

		if (e->d_type == DT_REG)
			strvec_pushf(archiver_args, "--add-file=%s", buf.buf);
		else if (e->d_type != DT_DIR)
			warning(_("skipping '%s', which is neither file nor "
				  "directory"), buf.buf);
		else if (recurse &&
			 add_directory_to_archiver(archiver_args,
						   buf.buf, recurse) < 0)
			res = -1;
	}

	closedir(dir);
	strbuf_release(&buf);
	return res;
}

#ifndef WIN32
#include <sys/statvfs.h>
#endif

static int get_disk_info(struct strbuf *out)
{
#ifdef WIN32
	struct strbuf buf = STRBUF_INIT;
	char volume_name[MAX_PATH], fs_name[MAX_PATH];
	DWORD serial_number, component_length, flags;
	ULARGE_INTEGER avail2caller, total, avail;

	strbuf_realpath(&buf, ".", 1);
	if (!GetDiskFreeSpaceExA(buf.buf, &avail2caller, &total, &avail)) {
		error(_("could not determine free disk size for '%s'"),
		      buf.buf);
		strbuf_release(&buf);
		return -1;
	}

	strbuf_setlen(&buf, offset_1st_component(buf.buf));
	if (!GetVolumeInformationA(buf.buf, volume_name, sizeof(volume_name),
				   &serial_number, &component_length, &flags,
				   fs_name, sizeof(fs_name))) {
		error(_("could not get info for '%s'"), buf.buf);
		strbuf_release(&buf);
		return -1;
	}
	strbuf_addf(out, "Available space on '%s': ", buf.buf);
	strbuf_humanise_bytes(out, avail2caller.QuadPart);
	strbuf_addch(out, '\n');
	strbuf_release(&buf);
#else
	struct strbuf buf = STRBUF_INIT;
	struct statvfs stat;

	strbuf_realpath(&buf, ".", 1);
	if (statvfs(buf.buf, &stat) < 0) {
		error_errno(_("could not determine free disk size for '%s'"),
			    buf.buf);
		strbuf_release(&buf);
		return -1;
	}

	strbuf_addf(out, "Available space on '%s': ", buf.buf);
	strbuf_humanise_bytes(out, st_mult(stat.f_bsize, stat.f_bavail));
	strbuf_addf(out, " (mount flags 0x%lx)\n", stat.f_flag);
	strbuf_release(&buf);
#endif
	return 0;
}

static int create_diagnostics_archive(struct strbuf *zip_path)
{
	struct strvec archiver_args = STRVEC_INIT;
	char **argv_copy = NULL;
	int stdout_fd = -1, archiver_fd = -1;
	struct strbuf buf = STRBUF_INIT;
	int res = 0;

	stdout_fd = dup(1);
	if (stdout_fd < 0) {
		res = error_errno(_("could not duplicate stdout"));
		goto diagnose_cleanup;
	}

	archiver_fd = xopen(zip_path->buf, O_CREAT | O_WRONLY | O_TRUNC, 0666);
	if (archiver_fd < 0 || dup2(archiver_fd, 1) < 0) {
		res = error_errno(_("could not redirect output"));
		goto diagnose_cleanup;
	}

	init_zip_archiver();
	strvec_pushl(&archiver_args, "scalar-diagnose", "--format=zip", NULL);

	strbuf_reset(&buf);
	strbuf_addstr(&buf, "Collecting diagnostic info\n\n");
	get_version_info(&buf, 1);

	strbuf_addf(&buf, "Repository root: %s\n", the_repository->worktree);
	get_disk_info(&buf);
	write_or_die(stdout_fd, buf.buf, buf.len);
	strvec_pushf(&archiver_args,
		     "--add-virtual-file=diagnostics.log:%.*s",
		     (int)buf.len, buf.buf);

	strbuf_reset(&buf);
	strbuf_addstr(&buf, "--add-virtual-file=packs-local.txt:");
	dir_file_stats(the_repository->objects->odb, &buf);
	foreach_alt_odb(dir_file_stats, &buf);
	strvec_push(&archiver_args, buf.buf);

	strbuf_reset(&buf);
	strbuf_addstr(&buf, "--add-virtual-file=objects-local.txt:");
	loose_objs_stats(&buf, ".git/objects");
	strvec_push(&archiver_args, buf.buf);

	if ((res = add_directory_to_archiver(&archiver_args, ".git", 0)) ||
	    (res = add_directory_to_archiver(&archiver_args, ".git/hooks", 0)) ||
	    (res = add_directory_to_archiver(&archiver_args, ".git/info", 0)) ||
	    (res = add_directory_to_archiver(&archiver_args, ".git/logs", 1)) ||
	    (res = add_directory_to_archiver(&archiver_args, ".git/objects/info", 0)))
		goto diagnose_cleanup;

	strvec_pushl(&archiver_args, "--prefix=",
		     oid_to_hex(the_hash_algo->empty_tree), "--", NULL);

	/* `write_archive()` modifies the `argv` passed to it. Let it. */
	argv_copy = xmemdupz(archiver_args.v,
			     sizeof(char *) * archiver_args.nr);
	res = write_archive(archiver_args.nr, (const char **)argv_copy, NULL,
			    the_repository, NULL, 0);
	if (res) {
		error(_("failed to write archive"));
		goto diagnose_cleanup;
	}

	if (!res)
		fprintf(stderr, "\n"
			"Diagnostics complete.\n"
			"All of the gathered info is captured in '%s'\n",
			zip_path->buf);

diagnose_cleanup:
	if (archiver_fd >= 0) {
		close(1);
		dup2(stdout_fd, 1);
	}
	free(argv_copy);
	strvec_clear(&archiver_args);
	strbuf_release(&buf);

	return res;
}

int cmd_bugreport(int argc, const char **argv, const char *prefix)
{
	struct strbuf buffer = STRBUF_INIT;
	struct strbuf report_path = STRBUF_INIT;
	int report = -1;
	time_t now = time(NULL);
	struct tm tm;
	int diagnose = 0;
	char *option_output = NULL;
	char *option_suffix = "%Y-%m-%d-%H%M";
	const char *user_relative_path = NULL;
	char *prefixed_filename;
	size_t output_path_len;

	const struct option bugreport_options[] = {
		OPT_BOOL(0, "diagnose", &diagnose,
			 N_("generate a diagnostics zip archive")),
		OPT_STRING('o', "output-directory", &option_output, N_("path"),
			   N_("specify a destination for the bugreport file(s)")),
		OPT_STRING('s', "suffix", &option_suffix, N_("format"),
			   N_("specify a strftime format suffix for the filename(s)")),
		OPT_END()
	};

	argc = parse_options(argc, argv, prefix, bugreport_options,
			     bugreport_usage, 0);

	/* Prepare the path to put the result */
	prefixed_filename = prefix_filename(prefix,
					    option_output ? option_output : "");
	strbuf_addstr(&report_path, prefixed_filename);
	strbuf_complete(&report_path, '/');
	output_path_len = report_path.len;

	strbuf_addstr(&report_path, "git-bugreport-");
	strbuf_addftime(&report_path, option_suffix, localtime_r(&now, &tm), 0, 0);
	strbuf_addstr(&report_path, ".txt");

	switch (safe_create_leading_directories(report_path.buf)) {
	case SCLD_OK:
	case SCLD_EXISTS:
		break;
	default:
		die(_("could not create leading directories for '%s'"),
		    report_path.buf);
	}

	/* Prepare diagnostics, if requested */
	if (diagnose) {
		struct strbuf zip_path = STRBUF_INIT;
		strbuf_add(&zip_path, report_path.buf, output_path_len);
		strbuf_addstr(&zip_path, "git-diagnostics-");
		strbuf_addftime(&zip_path, option_suffix, localtime_r(&now, &tm), 0, 0);
		strbuf_addstr(&zip_path, ".zip");

		if (create_diagnostics_archive(&zip_path))
			die_errno(_("unable to create diagnostics archive %s"), zip_path.buf);

		strbuf_release(&zip_path);
	}

	/* Prepare the report contents */
	get_bug_template(&buffer);

	get_header(&buffer, _("System Info"));
	get_system_info(&buffer);

	get_header(&buffer, _("Enabled Hooks"));
	get_populated_hooks(&buffer, !startup_info->have_repository);

	/* fopen doesn't offer us an O_EXCL alternative, except with glibc. */
	report = xopen(report_path.buf, O_CREAT | O_EXCL | O_WRONLY, 0666);

	if (write_in_full(report, buffer.buf, buffer.len) < 0)
		die_errno(_("unable to write to %s"), report_path.buf);

	close(report);

	/*
	 * We want to print the path relative to the user, but we still need the
	 * path relative to us to give to the editor.
	 */
	if (!(prefix && skip_prefix(report_path.buf, prefix, &user_relative_path)))
		user_relative_path = report_path.buf;
	fprintf(stderr, _("Created new report at '%s'.\n"),
		user_relative_path);

	free(prefixed_filename);
	UNLEAK(buffer);
	UNLEAK(report_path);
	return !!launch_editor(report_path.buf, NULL, NULL);
}
