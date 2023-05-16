#ifndef COMMON_H
#define COMMON_H

#include "git-compat-util.h"
#include "wrapper.h"
#include "usage.h"

/*
 * ARRAY_SIZE - get the number of elements in a visible array
 * @x: the array whose size you want.
 *
 * This does not work on pointers, or arrays declared as [], or
 * function parameters.  With correct compiler support, such usage
 * will cause a build error (see the build_assert_or_zero macro).
 */
#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]) + BARF_UNLESS_AN_ARRAY(x))

#define bitsizeof(x)  (CHAR_BIT * sizeof(x))

#define maximum_signed_value_of_type(a) \
    (INTMAX_MAX >> (bitsizeof(intmax_t) - bitsizeof(a)))

#define maximum_unsigned_value_of_type(a) \
    (UINTMAX_MAX >> (bitsizeof(uintmax_t) - bitsizeof(a)))

/*
 * Signed integer overflow is undefined in C, so here's a helper macro
 * to detect if the sum of two integers will overflow.
 *
 * Requires: a >= 0, typeof(a) equals typeof(b)
 */
#define signed_add_overflows(a, b) \
    ((b) > maximum_signed_value_of_type(a) - (a))

#define unsigned_add_overflows(a, b) \
    ((b) > maximum_unsigned_value_of_type(a) - (a))

/*
 * Returns true if the multiplication of "a" and "b" will
 * overflow. The types of "a" and "b" must match and must be unsigned.
 * Note that this macro evaluates "a" twice!
 */
#define unsigned_mult_overflows(a, b) \
    ((a) && (b) > maximum_unsigned_value_of_type(a) / (a))

/*
 * Returns true if the left shift of "a" by "shift" bits will
 * overflow. The type of "a" must be unsigned.
 */
#define unsigned_left_shift_overflows(a, shift) \
    ((shift) < bitsizeof(a) && \
     (a) > maximum_unsigned_value_of_type(a) >> (shift))

#define MSB(x, bits) ((x) & TYPEOF(x)(~0ULL << (bitsizeof(x) - (bits))))
#define HAS_MULTI_BITS(i)  ((i) & ((i) - 1))  /* checks if an integer has more than 1 bit set */

#define DIV_ROUND_UP(n,d) (((n) + (d) - 1) / (d))

/* Approximation of the length of the decimal representation of this type. */
#define decimal_length(x)	((int)(sizeof(x) * 2.56 + 0.5) + 1)

/*
 * If the string "str" begins with the string found in "prefix", return 1.
 * The "out" parameter is set to "str + strlen(prefix)" (i.e., to the point in
 * the string right after the prefix).
 *
 * Otherwise, return 0 and leave "out" untouched.
 *
 * Examples:
 *
 *   [extract branch name, fail if not a branch]
 *   if (!skip_prefix(ref, "refs/heads/", &branch)
 *	return -1;
 *
 *   [skip prefix if present, otherwise use whole string]
 *   skip_prefix(name, "refs/heads/", &name);
 */
static inline int skip_prefix(const char *str, const char *prefix,
			      const char **out)
{
	do {
		if (!*prefix) {
			*out = str;
			return 1;
		}
	} while (*str++ == *prefix++);
	return 0;
}

/*
 * Like skip_prefix, but promises never to read past "len" bytes of the input
 * buffer, and returns the remaining number of bytes in "out" via "outlen".
 */
static inline int skip_prefix_mem(const char *buf, size_t len,
				  const char *prefix,
				  const char **out, size_t *outlen)
{
	size_t prefix_len = strlen(prefix);
	if (prefix_len <= len && !memcmp(buf, prefix, prefix_len)) {
		*out = buf + prefix_len;
		*outlen = len - prefix_len;
		return 1;
	}
	return 0;
}

/*
 * If buf ends with suffix, return 1 and subtract the length of the suffix
 * from *len. Otherwise, return 0 and leave *len untouched.
 */
static inline int strip_suffix_mem(const char *buf, size_t *len,
				   const char *suffix)
{
	size_t suflen = strlen(suffix);
	if (*len < suflen || memcmp(buf + (*len - suflen), suffix, suflen))
		return 0;
	*len -= suflen;
	return 1;
}

/*
 * If str ends with suffix, return 1 and set *len to the size of the string
 * without the suffix. Otherwise, return 0 and set *len to the size of the
 * string.
 *
 * Note that we do _not_ NUL-terminate str to the new length.
 */
static inline int strip_suffix(const char *str, const char *suffix, size_t *len)
{
	*len = strlen(str);
	return strip_suffix_mem(str, len, suffix);
}

#define SWAP(a, b) do {						\
	void *_swap_a_ptr = &(a);				\
	void *_swap_b_ptr = &(b);				\
	unsigned char _swap_buffer[sizeof(a)];			\
	memcpy(_swap_buffer, _swap_a_ptr, sizeof(a));		\
	memcpy(_swap_a_ptr, _swap_b_ptr, sizeof(a) +		\
	       BUILD_ASSERT_OR_ZERO(sizeof(a) == sizeof(b)));	\
	memcpy(_swap_b_ptr, _swap_buffer, sizeof(a));		\
} while (0)

static inline size_t st_add(size_t a, size_t b)
{
	if (unsigned_add_overflows(a, b))
		die("size_t overflow: %"PRIuMAX" + %"PRIuMAX,
		    (uintmax_t)a, (uintmax_t)b);
	return a + b;
}
#define st_add3(a,b,c)   st_add(st_add((a),(b)),(c))
#define st_add4(a,b,c,d) st_add(st_add3((a),(b),(c)),(d))

static inline size_t st_mult(size_t a, size_t b)
{
	if (unsigned_mult_overflows(a, b))
		die("size_t overflow: %"PRIuMAX" * %"PRIuMAX,
		    (uintmax_t)a, (uintmax_t)b);
	return a * b;
}

static inline size_t st_sub(size_t a, size_t b)
{
	if (a < b)
		die("size_t underflow: %"PRIuMAX" - %"PRIuMAX,
		    (uintmax_t)a, (uintmax_t)b);
	return a - b;
}

static inline size_t st_left_shift(size_t a, unsigned shift)
{
	if (unsigned_left_shift_overflows(a, shift))
		die("size_t overflow: %"PRIuMAX" << %u",
		    (uintmax_t)a, shift);
	return a << shift;
}

static inline unsigned long cast_size_t_to_ulong(size_t a)
{
	if (a != (unsigned long)a)
		die("object too large to read on this platform: %"
		    PRIuMAX" is cut off to %lu",
		    (uintmax_t)a, (unsigned long)a);
	return (unsigned long)a;
}

static inline int cast_size_t_to_int(size_t a)
{
	if (a > INT_MAX)
		die("number too large to represent as int on this platform: %"PRIuMAX,
		    (uintmax_t)a);
	return (int)a;
}


/*
 * FREE_AND_NULL(ptr) is like free(ptr) followed by ptr = NULL. Note
 * that ptr is used twice, so don't pass e.g. ptr++.
 */
#define FREE_AND_NULL(p) do { free(p); (p) = NULL; } while (0)

#define alloc_nr(x) (((x)+16)*3/2)

/**
 * Dynamically growing an array using realloc() is error prone and boring.
 *
 * Define your array with:
 *
 * - a pointer (`item`) that points at the array, initialized to `NULL`
 *   (although please name the variable based on its contents, not on its
 *   type);
 *
 * - an integer variable (`alloc`) that keeps track of how big the current
 *   allocation is, initialized to `0`;
 *
 * - another integer variable (`nr`) to keep track of how many elements the
 *   array currently has, initialized to `0`.
 *
 * Then before adding `n`th element to the item, call `ALLOC_GROW(item, n,
 * alloc)`.  This ensures that the array can hold at least `n` elements by
 * calling `realloc(3)` and adjusting `alloc` variable.
 *
 * ------------
 * sometype *item;
 * size_t nr;
 * size_t alloc
 *
 * for (i = 0; i < nr; i++)
 * 	if (we like item[i] already)
 * 		return;
 *
 * // we did not like any existing one, so add one
 * ALLOC_GROW(item, nr + 1, alloc);
 * item[nr++] = value you like;
 * ------------
 *
 * You are responsible for updating the `nr` variable.
 *
 * If you need to specify the number of elements to allocate explicitly
 * then use the macro `REALLOC_ARRAY(item, alloc)` instead of `ALLOC_GROW`.
 *
 * Consider using ALLOC_GROW_BY instead of ALLOC_GROW as it has some
 * added niceties.
 *
 * DO NOT USE any expression with side-effect for 'x', 'nr', or 'alloc'.
 */
#define ALLOC_GROW(x, nr, alloc) \
	do { \
		if ((nr) > alloc) { \
			if (alloc_nr(alloc) < (nr)) \
				alloc = (nr); \
			else \
				alloc = alloc_nr(alloc); \
			REALLOC_ARRAY(x, alloc); \
		} \
	} while (0)

/*
 * Similar to ALLOC_GROW but handles updating of the nr value and
 * zeroing the bytes of the newly-grown array elements.
 *
 * DO NOT USE any expression with side-effect for any of the
 * arguments.
 */
#define ALLOC_GROW_BY(x, nr, increase, alloc) \
	do { \
		if (increase) { \
			size_t new_nr = nr + (increase); \
			if (new_nr < nr) \
				BUG("negative growth in ALLOC_GROW_BY"); \
			ALLOC_GROW(x, new_nr, alloc); \
			memset((x) + nr, 0, sizeof(*(x)) * (increase)); \
			nr = new_nr; \
		} \
	} while (0)

#define ALLOC_ARRAY(x, alloc) (x) = xmalloc(st_mult(sizeof(*(x)), (alloc)))
#define CALLOC_ARRAY(x, alloc) (x) = xcalloc((alloc), sizeof(*(x)))
#define REALLOC_ARRAY(x, alloc) (x) = xrealloc((x), st_mult(sizeof(*(x)), (alloc)))

#define COPY_ARRAY(dst, src, n) copy_array((dst), (src), (n), sizeof(*(dst)) + \
	BARF_UNLESS_COPYABLE((dst), (src)))
static inline void copy_array(void *dst, const void *src, size_t n, size_t size)
{
	if (n)
		memcpy(dst, src, st_mult(size, n));
}

#define MOVE_ARRAY(dst, src, n) move_array((dst), (src), (n), sizeof(*(dst)) + \
	BARF_UNLESS_COPYABLE((dst), (src)))
static inline void move_array(void *dst, const void *src, size_t n, size_t size)
{
	if (n)
		memmove(dst, src, st_mult(size, n));
}

#define DUP_ARRAY(dst, src, n) do { \
	size_t dup_array_n_ = (n); \
	COPY_ARRAY(ALLOC_ARRAY((dst), dup_array_n_), (src), dup_array_n_); \
} while (0)

/*
 * These functions help you allocate structs with flex arrays, and copy
 * the data directly into the array. For example, if you had:
 *
 *   struct foo {
 *     int bar;
 *     char name[FLEX_ARRAY];
 *   };
 *
 * you can do:
 *
 *   struct foo *f;
 *   FLEX_ALLOC_MEM(f, name, src, len);
 *
 * to allocate a "foo" with the contents of "src" in the "name" field.
 * The resulting struct is automatically zero'd, and the flex-array field
 * is NUL-terminated (whether the incoming src buffer was or not).
 *
 * The FLEXPTR_* variants operate on structs that don't use flex-arrays,
 * but do want to store a pointer to some extra data in the same allocated
 * block. For example, if you have:
 *
 *   struct foo {
 *     char *name;
 *     int bar;
 *   };
 *
 * you can do:
 *
 *   struct foo *f;
 *   FLEXPTR_ALLOC_STR(f, name, src);
 *
 * and "name" will point to a block of memory after the struct, which will be
 * freed along with the struct (but the pointer can be repointed anywhere).
 *
 * The *_STR variants accept a string parameter rather than a ptr/len
 * combination.
 *
 * Note that these macros will evaluate the first parameter multiple
 * times, and it must be assignable as an lvalue.
 */
#define FLEX_ALLOC_MEM(x, flexname, buf, len) do { \
	size_t flex_array_len_ = (len); \
	(x) = xcalloc(1, st_add3(sizeof(*(x)), flex_array_len_, 1)); \
	memcpy((void *)(x)->flexname, (buf), flex_array_len_); \
} while (0)
#define FLEXPTR_ALLOC_MEM(x, ptrname, buf, len) do { \
	size_t flex_array_len_ = (len); \
	(x) = xcalloc(1, st_add3(sizeof(*(x)), flex_array_len_, 1)); \
	memcpy((x) + 1, (buf), flex_array_len_); \
	(x)->ptrname = (void *)((x)+1); \
} while(0)
#define FLEX_ALLOC_STR(x, flexname, str) \
	FLEX_ALLOC_MEM((x), flexname, (str), strlen(str))
#define FLEXPTR_ALLOC_STR(x, ptrname, str) \
	FLEXPTR_ALLOC_MEM((x), ptrname, (str), strlen(str))

static inline char *xstrdup_or_null(const char *str)
{
	return str ? xstrdup(str) : NULL;
}

static inline size_t xsize_t(off_t len)
{
	if (len < 0 || (uintmax_t) len > SIZE_MAX)
		die("Cannot handle files this big");
	return (size_t) len;
}

/* in ctype.c, for kwset users */
extern const unsigned char tolower_trans_tbl[256];

/* Sane ctype - no locale, and works with signed chars */
#undef isascii
#undef isspace
#undef isdigit
#undef isalpha
#undef isalnum
#undef isprint
#undef islower
#undef isupper
#undef tolower
#undef toupper
#undef iscntrl
#undef ispunct
#undef isxdigit

extern const unsigned char sane_ctype[256];
extern const signed char hexval_table[256];
#define GIT_SPACE 0x01
#define GIT_DIGIT 0x02
#define GIT_ALPHA 0x04
#define GIT_GLOB_SPECIAL 0x08
#define GIT_REGEX_SPECIAL 0x10
#define GIT_PATHSPEC_MAGIC 0x20
#define GIT_CNTRL 0x40
#define GIT_PUNCT 0x80
#define sane_istest(x,mask) ((sane_ctype[(unsigned char)(x)] & (mask)) != 0)
#define isascii(x) (((x) & ~0x7f) == 0)
#define isspace(x) sane_istest(x,GIT_SPACE)
#define isdigit(x) sane_istest(x,GIT_DIGIT)
#define isalpha(x) sane_istest(x,GIT_ALPHA)
#define isalnum(x) sane_istest(x,GIT_ALPHA | GIT_DIGIT)
#define isprint(x) ((x) >= 0x20 && (x) <= 0x7e)
#define islower(x) sane_iscase(x, 1)
#define isupper(x) sane_iscase(x, 0)
#define is_glob_special(x) sane_istest(x,GIT_GLOB_SPECIAL)
#define is_regex_special(x) sane_istest(x,GIT_GLOB_SPECIAL | GIT_REGEX_SPECIAL)
#define iscntrl(x) (sane_istest(x,GIT_CNTRL))
#define ispunct(x) sane_istest(x, GIT_PUNCT | GIT_REGEX_SPECIAL | \
		GIT_GLOB_SPECIAL | GIT_PATHSPEC_MAGIC)
#define isxdigit(x) (hexval_table[(unsigned char)(x)] != -1)
#define tolower(x) sane_case((unsigned char)(x), 0x20)
#define toupper(x) sane_case((unsigned char)(x), 0)
#define is_pathspec_magic(x) sane_istest(x,GIT_PATHSPEC_MAGIC)

static inline int sane_case(int x, int high)
{
	if (sane_istest(x, GIT_ALPHA))
		x = (x & ~0x20) | high;
	return x;
}

static inline int sane_iscase(int x, int is_lower)
{
	if (!sane_istest(x, GIT_ALPHA))
		return 0;

	if (is_lower)
		return (x & 0x20) != 0;
	else
		return (x & 0x20) == 0;
}

/*
 * Like skip_prefix, but compare case-insensitively. Note that the comparison
 * is done via tolower(), so it is strictly ASCII (no multi-byte characters or
 * locale-specific conversions).
 */
static inline int skip_iprefix(const char *str, const char *prefix,
			       const char **out)
{
	do {
		if (!*prefix) {
			*out = str;
			return 1;
		}
	} while (tolower(*str++) == tolower(*prefix++));
	return 0;
}

/*
 * Like skip_prefix_mem, but compare case-insensitively. Note that the
 * comparison is done via tolower(), so it is strictly ASCII (no multi-byte
 * characters or locale-specific conversions).
 */
static inline int skip_iprefix_mem(const char *buf, size_t len,
				   const char *prefix,
				   const char **out, size_t *outlen)
{
	do {
		if (!*prefix) {
			*out = buf;
			*outlen = len;
			return 1;
		}
	} while (len-- > 0 && tolower(*buf++) == tolower(*prefix++));
	return 0;
}

static inline int strtoul_ui(char const *s, int base, unsigned int *result)
{
	unsigned long ul;
	char *p;

	errno = 0;
	/* negative values would be accepted by strtoul */
	if (strchr(s, '-'))
		return -1;
	ul = strtoul(s, &p, base);
	if (errno || *p || p == s || (unsigned int) ul != ul)
		return -1;
	*result = ul;
	return 0;
}

static inline int strtol_i(char const *s, int base, int *result)
{
	long ul;
	char *p;

	errno = 0;
	ul = strtol(s, &p, base);
	if (errno || *p || p == s || (int) ul != ul)
		return -1;
	*result = ul;
	return 0;
}

static inline int regexec_buf(const regex_t *preg, const char *buf, size_t size,
			      size_t nmatch, regmatch_t pmatch[], int eflags)
{
	assert(nmatch > 0 && pmatch);
	pmatch[0].rm_so = 0;
	pmatch[0].rm_eo = size;
	return regexec(preg, buf, nmatch, pmatch, eflags | REG_STARTEND);
}

/*
 * Our code often opens a path to an optional file, to work on its
 * contents when we can successfully open it.  We can ignore a failure
 * to open if such an optional file does not exist, but we do want to
 * report a failure in opening for other reasons (e.g. we got an I/O
 * error, or the file is there, but we lack the permission to open).
 *
 * Call this function after seeing an error from open() or fopen() to
 * see if the errno indicates a missing file that we can safely ignore.
 */
static inline int is_missing_file_error(int errno_)
{
	return (errno_ == ENOENT || errno_ == ENOTDIR);
}

/*
 * container_of - Get the address of an object containing a field.
 *
 * @ptr: pointer to the field.
 * @type: type of the object.
 * @member: name of the field within the object.
 */
#define container_of(ptr, type, member) \
	((type *) ((char *)(ptr) - offsetof(type, member)))

/*
 * helper function for `container_of_or_null' to avoid multiple
 * evaluation of @ptr
 */
static inline void *container_of_or_null_offset(void *ptr, size_t offset)
{
	return ptr ? (char *)ptr - offset : NULL;
}

/*
 * like `container_of', but allows returned value to be NULL
 */
#define container_of_or_null(ptr, type, member) \
	(type *)container_of_or_null_offset(ptr, offsetof(type, member))


#endif
