#include "test-tool.h"
#include "cache.h"
#include "tree.h"
#include "cache-tree.h"
#include "parse-options.h"

static char const * const test_cache_tree_usage[] = {
	N_("test-tool cache-tree <options> (prime|repair)"),
	NULL
};

int cmd__cache_tree(int argc, const char **argv)
{
	struct object_id oid;
	struct tree *tree;
	int fresh = 0;
	int count = 1;
	int i;

	struct option options[] = {
		OPT_BOOL(0, "fresh", &fresh,
			 N_("clear the cache tree before each repetition")),
		OPT_INTEGER_F(0, "count", &count, N_("number of times to repeat the operation"),
			      PARSE_OPT_NONEG),
		OPT_END()
	};

	setup_git_directory();

	parse_options(argc, argv, NULL, options, test_cache_tree_usage, 0);

	if (read_cache() < 0)
		die("unable to read index file");

	get_oid("HEAD", &oid);
	tree = parse_tree_indirect(&oid);
	for (i = 0; i < count; i++) {
		if (fresh)
			cache_tree_free(&the_index.cache_tree);

		if (!argc)
			die("Must specify subcommand");
		else if (!strcmp(argv[0], "prime"))
			prime_cache_tree(the_repository, &the_index, tree);
		else if (!strcmp(argv[0], "update"))
			cache_tree_update(&the_index, WRITE_TREE_SILENT | WRITE_TREE_REPAIR);
		else
			die("Unknown command %s", argv[0]);
	}

	return 0;
}
