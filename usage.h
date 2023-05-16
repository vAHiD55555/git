#ifndef USAGE_H
#define USAGE_H

#include "git-compat-util.h"

/* General helper functions */
NORETURN void usage(const char *err);
NORETURN void usagef(const char *err, ...) __attribute__((format (printf, 1, 2)));
NORETURN void die(const char *err, ...) __attribute__((format (printf, 1, 2)));
NORETURN void die_errno(const char *err, ...) __attribute__((format (printf, 1, 2)));
int error(const char *err, ...) __attribute__((format (printf, 1, 2)));
int error_errno(const char *err, ...) __attribute__((format (printf, 1, 2)));
int die_message(const char *err, ...) __attribute__((format (printf, 1, 2)));
int die_message_errno(const char *err, ...) __attribute__((format (printf, 1, 2)));

void warning(const char *err, ...) __attribute__((format (printf, 1, 2)));
void warning_errno(const char *err, ...) __attribute__((format (printf, 1, 2)));

/*
 * Let callers be aware of the constant return value; this can help
 * gcc with -Wuninitialized analysis. We restrict this trick to gcc, though,
 * because other compilers may be confused by this.
 */
#if defined(__GNUC__)
static inline int const_error(void)
{
	return -1;
}
#define error(...) (error(__VA_ARGS__), const_error())
#define error_errno(...) (error_errno(__VA_ARGS__), const_error())
#endif

typedef void (*report_fn)(const char *, va_list params);

void set_die_routine(NORETURN_PTR report_fn routine);
report_fn get_die_message_routine(void);
void set_error_routine(report_fn routine);
report_fn get_error_routine(void);
void set_warn_routine(report_fn routine);
report_fn get_warn_routine(void);
void set_die_is_recursing_routine(int (*routine)(void));

/* usage.c: only to be used for testing BUG() implementation (see test-tool) */
extern int BUG_exit_code;

/* usage.c: if bug() is called we should have a BUG_if_bug() afterwards */
extern int bug_called_must_BUG;

__attribute__((format (printf, 3, 4))) NORETURN
void BUG_fl(const char *file, int line, const char *fmt, ...);
#define BUG(...) BUG_fl(__FILE__, __LINE__, __VA_ARGS__)
__attribute__((format (printf, 3, 4)))
void bug_fl(const char *file, int line, const char *fmt, ...);
#define bug(...) bug_fl(__FILE__, __LINE__, __VA_ARGS__)
#define BUG_if_bug(...) do { \
	if (bug_called_must_BUG) \
		BUG_fl(__FILE__, __LINE__, __VA_ARGS__); \
} while (0)

#endif /* USAGE_H */
