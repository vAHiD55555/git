#include "test-tool.h"
#include "git-compat-util.h"

/*
 * Read stdin and print a hexdump to stdout.
 */
int cmd__hexdump(int argc, const char **argv)
{
	char buf[1024];
	ssize_t i, len;

	for (;;) {
		len = xread(0, buf, sizeof(buf));
		if (len < 0)
			die_errno("failure reading stdin");
		if (!len)
			break;

		for (i = 0; i < len; i++)
			printf("%02x ", (unsigned char)buf[i]);
	}

	return 0;
}
