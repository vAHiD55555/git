#include "test-tool.h"
#include "strbuf.h"

static const char *usage_msg = "test-tool readlink file";

int cmd__readlink(int ac, const char **av)
{
	struct strbuf buf = STRBUF_INIT;
	int ret;

	if (ac != 2 || !av[1])
		usage(usage_msg);

	ret = strbuf_readlink(&buf, av[1], 0);
	if (!ret)
		printf("%s\n", buf.buf);
	strbuf_release(&buf);
	return ret;
}
