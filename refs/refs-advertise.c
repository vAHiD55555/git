#include "../cache.h"
#include "../config.h"
#include "../strbuf.h"
#include "../hook.h"
#include "../sigchain.h"
#include "../pkt-line.h"
#include "../refs.h"
#include "../run-command.h"
#include "connect.h"
#include "ref-cache.h"
#include "refs-advertise.h"

struct advertise_refs_filter {
	struct child_process proc;
	struct packet_reader reader;
};

static struct advertise_refs_filter *hook_filter = NULL;

void create_advertise_refs_filter(const char *command) {
	struct advertise_refs_filter *filter;
	struct child_process *proc;
	struct packet_reader *reader;
	const char *hook_path;
	int command_support = 0;
	int version = 0;
	int code;

	if (hook_filter != NULL)
		return;

	hook_path = find_hook("refs-advertise");
	if (!hook_path) {
		return;
	}

	filter = (struct advertise_refs_filter *) xcalloc (1, sizeof (struct advertise_refs_filter));
	proc = &filter->proc;
	reader = &filter->reader;

	child_process_init(proc);
	strvec_push(&proc->args, hook_path);
	proc->in = -1;
	proc->out = -1;
	proc->trace2_hook_name = "refs-advertise";
	proc->err = 0;

	code = start_command(proc);
	if (code)
		die("can not run hook refs-advertise");

	sigchain_push(SIGPIPE, SIG_IGN);

	/* Version negotiaton */
	packet_reader_init(reader, proc->out, NULL, 0,
			   PACKET_READ_CHOMP_NEWLINE |
			   PACKET_READ_GENTLE_ON_EOF);
	code = packet_write_fmt_gently(proc->in, "version=1%c%s", '\0', command);
	if (!code)
		code = packet_flush_gently(proc->in);

	if (!code)
		for (;;) {
			int linelen;
			enum packet_read_status status;

			status = packet_reader_read(reader);
			if (status != PACKET_READ_NORMAL) {
				/* Check whether refs-advertise exited abnormally */
				if (status == PACKET_READ_EOF)
					die("can not read version message from hook refs-advertise");
				break;
			}

			if (reader->pktlen > 8 && starts_with(reader->line, "version=")) {
				version = atoi(reader->line + 8);
				linelen = strlen(reader->line);
				if (linelen < reader->pktlen) {
					const char *command_list = reader->line + linelen + 1;
					if (parse_feature_request(command_list, command)) {
						command_support = 1;
					}
				}
			}
		}

	if (code)
		die("can not read version message from hook refs-advertise");

	switch (version) {
	case 0:
		/* fallthrough */
	case 1:
		break;
	default:
		die(_("hook refs-advertise version '%d' is not supported"), version);
	}

	sigchain_pop(SIGPIPE);

	if (!command_support) {
		close(proc->in);
		close(proc->out);
		kill(proc->pid, SIGTERM);
		finish_command_in_signal(proc);
		free(filter);

		return;
	}

	hook_filter = filter;
	return;
}

void clean_advertise_refs_filter(void) {
	struct child_process *proc;

	if (!hook_filter) {
		return;
	}

	proc = &hook_filter->proc;

	close(proc->in);
	close(proc->out);
	kill(proc->pid, SIGTERM);
	finish_command_in_signal(proc);
	FREE_AND_NULL(hook_filter);
}

static int do_filter_advertise_ref(const char *refname, const struct object_id *oid) {
	struct child_process *proc;
	struct packet_reader *reader;
	struct strbuf buf = STRBUF_INIT;
	char *oid_hex;
	int code;

	proc = &hook_filter->proc;
	reader = &hook_filter->reader;
	if (oid)
		oid_hex = oid_to_hex(oid);
	else
		oid_hex = oid_to_hex(null_oid());

	code = packet_write_fmt_gently(proc->in, "ref %s %s", refname, oid_hex);
	if (code)
		die("hook refs-advertise died abnormally");

	code = packet_flush_gently(proc->in);
	if (code)
		die("hook refs-advertise died abnormally");

	for (;;) {
		enum packet_read_status status;

		status = packet_reader_read(reader);
		if (status != PACKET_READ_NORMAL) {
			/* Check whether refs-advertise exited abnormally */
			if (status == PACKET_READ_EOF)
				die("hook refs-advertise died abnormally");
			break;
		}

		strbuf_reset(&buf);
		strbuf_addstr(&buf, reader->line);
	}

	if (strncmp("ok ref ", buf.buf, 7))
		return -1;

	if (strcmp(refname, buf.buf + 7))
		return -1;

	return 0;
}

int filter_advertise_ref(const char *refname, const struct object_id *oid) {
	int result;

	if (!hook_filter) {
		return 0;
	}

	sigchain_push(SIGPIPE, SIG_IGN);
	result = do_filter_advertise_ref(refname, oid);
	sigchain_pop(SIGPIPE);

	return result;
}

static int do_filter_advertise_object(const struct object_id *oid) {
	struct child_process *proc;
	struct packet_reader *reader;
	struct strbuf buf = STRBUF_INIT;
	char *oid_hex;
	int code;

	proc = &hook_filter->proc;
	reader = &hook_filter->reader;
	oid_hex = oid_to_hex(oid);

	code = packet_write_fmt_gently(proc->in, "obj %s", oid_hex);
	if (code)
		die("hook refs-advertise died abnormally");

	code = packet_flush_gently(proc->in);
	if (code)
		die("hook refs-advertise died abnormally");

	for (;;) {
		enum packet_read_status status;

		status = packet_reader_read(reader);
		if (status != PACKET_READ_NORMAL) {
			/* Check whether refs-advertise exited abnormally */
			if (status == PACKET_READ_EOF)
				die("hook refs-advertise died abnormally");
			break;
		}

		strbuf_reset(&buf);
		strbuf_addstr(&buf, reader->line);
	}

	if (strncmp("ok obj ", buf.buf, 7))
		return -1;

	if (strcmp(oid_hex, buf.buf + 7))
		return -1;

	return 0;
}

int filter_advertise_object(const struct object_id *oid) {
	int result;

	if (!hook_filter || !oid) {
		return 0;
	}

	sigchain_push(SIGPIPE, SIG_IGN);
	result = do_filter_advertise_object(oid);
	sigchain_pop(SIGPIPE);

	return result;
}
