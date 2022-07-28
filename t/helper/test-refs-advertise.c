#include "cache.h"
#include "hash.h"
#include "config.h"
#include "connect.h"
#include "parse-options.h"
#include "pkt-line.h"
#include "sigchain.h"
#include "test-tool.h"

static const char *refs_advertise_usage[] = {
	"test-tool refs-advertise [<options>...]",
	NULL
};

static int can_upload_pack;
static int can_receive_pack;
static int can_ls_refs;
static int die_read_version;
static int die_write_version;
static int die_read_first_ref;
static int die_read_second_ref;
static int die_filter_refs;
static int upload_pack;
static int receive_pack;
static int ls_refs;
static int verbose;
static int version = 1;
static int first_ref;
static int second_ref;
static int hash_size = GIT_SHA1_HEXSZ;
static struct string_list returns = STRING_LIST_INIT_NODUP;

struct command {
	struct command *next;
	const char *error_string;
	unsigned int skip_update:1,
		     did_not_exist:1;
	int index;
	struct object_id old_oid;
	struct object_id new_oid;
	char ref_name[FLEX_ARRAY]; /* more */
};

static void refs_advertise_verison(struct packet_reader *reader) {
	int server_version = 0;

	if (die_read_version)
		die("die with the --die-read-version option");

	for (;;) {
		int linelen;

		if (packet_reader_read(reader) != PACKET_READ_NORMAL)
			break;

		/* Ignore version negotiation for version 0 */
		if (version == 0)
			continue;

		if (reader->pktlen > 8 && starts_with(reader->line, "version=")) {
			server_version = atoi(reader->line+8);
			if (server_version != 1)
				die("bad protocol version: %d", server_version);
			linelen = strlen(reader->line);
			if (linelen < reader->pktlen) {
				const char *feature_list = reader->line + linelen + 1;
				if (parse_feature_request(feature_list, "git-upload-pack"))
					upload_pack = 1;
				if (parse_feature_request(feature_list, "git-receive-pack"))
					receive_pack = 1;
				if (parse_feature_request(feature_list, "ls-refs"))
					ls_refs = 1;
			}
		}
	}

	if (die_write_version)
		die("die with the --die-write-version option");

	if (can_upload_pack || can_receive_pack || can_ls_refs)
		packet_write_fmt(1, "version=%d%c%s%s%s\n",
				version, '\0',
				can_upload_pack ? "git-upload-pack ": "",
				can_receive_pack? "git-receive-pack ": "",
				can_ls_refs? "ls-refs ": "");
	else
		packet_write_fmt(1, "version=%d\n", version);

	packet_flush(1);

	if ((upload_pack && !can_upload_pack) ||
		(receive_pack && !can_receive_pack) ||
		(ls_refs && !can_ls_refs)) {
			exit(0);
	}
}

static void refs_advertise_read_refs(struct packet_reader *reader)
{
	const char *p;
	struct strbuf buf = STRBUF_INIT;
	enum packet_read_status status;
	int filter_ok = 0;

	if (!first_ref) {
		if (die_read_first_ref)
			die("die with the --die-read-first-ref option");

		first_ref = 1;
	}

	if (first_ref && !second_ref) {
		if (die_read_second_ref)
			die("die with the --die-read-second-ref option");

		second_ref = 1;
	}

	for (;;) {
		status = packet_reader_read(reader);
		if (status == PACKET_READ_EOF)
			exit(0);

		if (status != PACKET_READ_NORMAL)
			break;

		p = reader->line;
		strbuf_reset(&buf);
		strbuf_addstr(&buf, reader->line);
	}

	p = buf.buf;

	if (unsorted_string_list_has_string(&returns, p)) {
		filter_ok = 1;
	}

	// if it's a ref filter request, we response without the commit id
	if ((buf.len > (hash_size + 1)) && (strncmp("obj ", buf.buf, 4)))
		strbuf_setlen(&buf, buf.len - (hash_size + 1));

	if (filter_ok) {
		packet_write_fmt(1, "%s %s\n", "ok", p);
	} else {
		packet_write_fmt(1, "%s %s\n", "ng", p);
	}

	if (die_filter_refs)
		die("die with the --die-filter-refs option");

	packet_flush(1);
}

int cmd__refs_advertise(int argc, const char **argv) {
	int nongit_ok = 0;
	struct packet_reader reader;
	const char *value = NULL;
	struct option options[] = {
		OPT_BOOL(0, "can-upload-pack", &can_upload_pack,
			 "support upload-pack command"),
		OPT_BOOL(0, "can-receive-pack", &can_receive_pack,
			 "support upload-pack command"),
		OPT_BOOL(0, "can-ls-refs", &can_ls_refs,
			 "support ls-refs command"),
		OPT_BOOL(0, "die-read-version", &die_read_version,
			 "die when reading version"),
		OPT_BOOL(0, "die-write-version", &die_write_version,
			 "die when writing version"),
		OPT_BOOL(0, "die-read-first-ref", &die_read_first_ref,
			 "die when reading first reference"),
		OPT_BOOL(0, "die-read-second-ref", &die_read_second_ref,
			 "die when reading second reference"),
		OPT_BOOL(0, "die-filter-refs", &die_filter_refs,
			 "die when filtering refs"),
		OPT_STRING_LIST('r', "return", &returns, "ref<SP>$refname<SP>$oid|obj<SP>$oid",
				"refs or objects that can advertise"),
		OPT__VERBOSE(&verbose, "be verbose"),
		OPT_INTEGER('V', "version", &version,
			    "use this protocol version number"),
		OPT_END()
	};

	setup_git_directory_gently(&nongit_ok);

	argc = parse_options(argc, argv, "test-tools", options, refs_advertise_usage, 0);
	if (argc > 0)
		usage_msg_opt("Too many arguments.", refs_advertise_usage, options);

	packet_reader_init(&reader, 0, NULL, 0, PACKET_READ_CHOMP_NEWLINE | PACKET_READ_GENTLE_ON_EOF);

	if (!git_config_get_value("extensions.objectformat", &value)) {
		if (!strcmp(value, "sha256"))
			hash_size = GIT_SHA256_HEXSZ;
	}

	refs_advertise_verison(&reader);
	for (;;) {
		refs_advertise_read_refs(&reader);
	}

	return 0;
}
