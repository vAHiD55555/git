#include "git-compat-util.h"
#include "khash.h"

/* use the actual functions to avoid infinite recursion */
#undef malloc
#undef calloc
#undef realloc
#undef free

/*
 * likewise avoid khash's instantiated code calling into xmalloc(),
 * which will have been compiled with the function redirects
 */
#define xmalloc malloc
#define xcalloc calloc
#define xrealloc realloc

static inline int ptr_hash(const void *ptr)
{
	return memhash(&ptr, sizeof(ptr));
}

static inline int ptr_eq(const void *a, const void *b)
{
	return a == b;
}

KHASH_INIT(ptr_len, const void *, size_t, 1, ptr_hash, ptr_eq);

static kh_ptr_len_t used_blocks;
static size_t used_cur, used_max;

static int should_trace(void)
{
	static int trace = -1;

	if (trace < 0) {
		/* avoid trace_*, as they may allocate */
		const char *x = getenv("GIT_TRACE_MALLOC");
		trace = x && !strcmp(x, "1");
	}
	return trace;
}

static void use_block(const void *ptr, size_t len)
{
	khint_t pos;
	int hash_ret;

	if (!should_trace())
		return;

	pos = kh_put_ptr_len(&used_blocks, ptr, &hash_ret);
	if (!hash_ret)
		BUG("marking used ptr %p twice!?", ptr);
	kh_value(&used_blocks, pos) = len;

	used_cur += len;
	if (used_cur > used_max) {
		used_max = used_cur;
		fprintf(stderr, "GIT_TRACE_MALLOC: new peak: %"PRIuMAX"\n",
			(uintmax_t)used_max);
	}
}

static void unuse_block(const void *ptr)
{
	khint_t pos;

	if (!should_trace())
		return;
	if (!ptr)
		return;

	pos = kh_get_ptr_len(&used_blocks, ptr);

	/*
	 * Don't complain if we don't find it, even though it _could_ be the
	 * sign of a bug. But we might also seem legitimate unaccounted-for
	 * sources (e.g., like libc getline() which calls directly into
	 * malloc).
	 */
	if (pos >= kh_end(&used_blocks))
		return;

	used_cur -= kh_value(&used_blocks, pos);
	kh_del_ptr_len(&used_blocks, pos);
}

void *profile_malloc(size_t len)
{
	void *ret = malloc(len);
	if (ret)
		use_block(ret, len);
	return ret;
}

void *profile_realloc(void *ptr, size_t len)
{
	void *ret = realloc(ptr, len);
	if (ret) {
		unuse_block(ptr);
		use_block(ret, len);
	}
	return ret;
}

void *profile_calloc(size_t n, size_t len)
{
	void *ret = calloc(n, len);
	if (ret) {
		size_t total = n * len; /* overflow-proof if calloc worked */
		use_block(ret, total);
	}
	return ret;
}

void profile_free(void *ptr)
{
	free(ptr);
	unuse_block(ptr);
}
