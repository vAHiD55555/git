#include "test-tool.h"
#include "cache.h"
#include "quote.h"

int cmd__unquote_c_style(int argc, const char **argv)
{
	struct strbuf buf = STRBUF_INIT;

	while (*++argv) {
		const char *p = *argv;

		if (unquote_c_style(&buf, p, &p) < 0)
			error("cannot unquote '%s'", *argv);
		else
			printf("%s\n", buf.buf);
		strbuf_reset(&buf);
	}
	return 0;
}

int cmd__quote_c_style(int argc, const char **argv)
{
	struct strbuf buf = STRBUF_INIT;

	while (*++argv) {
		const char *p = *argv;

		quote_c_style(p, &buf, NULL, 0);
		printf("%s\n", buf.buf);
		strbuf_reset(&buf);
	}
	return 0;
}
