#include "test-tool.h"
#include "parse-options.h"
#include "bundle-uri.h"
#include "strbuf.h"
#include "string-list.h"

static int cmd__bundle_uri_parse_key_values(int argc, const char **argv)
{
	const char *usage[] = {
		"test-tool bundle-uri parse-key-values <in",
		NULL
	};
	struct option options[] = {
		OPT_END(),
	};
	struct strbuf sb = STRBUF_INIT;
	struct bundle_list list;
	int err = 0;

	argc = parse_options(argc, argv, NULL, options, usage, 0);
	if (argc)
		goto usage;

	init_bundle_list(&list);
	while (strbuf_getline(&sb, stdin) != EOF) {
		if (bundle_uri_parse_line(&list, sb.buf) < 0)
			err = error("bad line: '%s'", sb.buf);
	}
	strbuf_release(&sb);

	print_bundle_list(stdout, &list);

	clear_bundle_list(&list);

	return !!err;

usage:
	usage_with_options(usage, options);
}

int cmd__bundle_uri(int argc, const char **argv)
{
	const char *usage[] = {
		"test-tool bundle-uri <subcommand> [<options>]",
		NULL
	};
	struct option options[] = {
		OPT_END(),
	};

	argc = parse_options(argc, argv, NULL, options, usage,
			     PARSE_OPT_STOP_AT_NON_OPTION |
			     PARSE_OPT_KEEP_ARGV0);
	if (argc == 1)
		goto usage;

	if (!strcmp(argv[1], "parse-key-values"))
		return cmd__bundle_uri_parse_key_values(argc - 1, argv + 1);
	error("there is no test-tool bundle-uri tool '%s'", argv[1]);

usage:
	usage_with_options(usage, options);
}
