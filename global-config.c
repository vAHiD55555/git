#include "git-compat-util.h"
#include "global-config.h"
#include "config.h"

static int global_ints[] = {
	[INT_CONFIG_NONE] = 0, /* unused*/
	[INT_CONFIG_TRUST_EXECUTABLE_BIT] = 1,
	[INT_CONFIG_TRUST_CTIME] = 1,
	[INT_CONFIG_QUOTE_PATH_FULLY] = 1,
	[INT_CONFIG_HAS_SYMLINKS] = 1,
};

/* Bitmask for the enum. */
static uint64_t global_ints_initialized;

static const char *global_int_names[] = {
	[INT_CONFIG_NONE] = NULL, /* unused*/
	[INT_CONFIG_TRUST_EXECUTABLE_BIT] = "core.filemode",
	[INT_CONFIG_TRUST_CTIME] = "core.trustctime",
	[INT_CONFIG_QUOTE_PATH_FULLY] = "core.quotepath",
	[INT_CONFIG_HAS_SYMLINKS] = "core.symlinks",
};

static int config_available;

void declare_config_available(void)
{
	config_available = 1;
}

int get_int_config_global(enum int_config_key key)
{
	uint64_t key_index;

	if (key < 0 || key >= sizeof(global_ints))
		BUG("invalid int_config_key %d", key);

	key_index = (uint64_t)1 << key;

	/*
	 * Is it too early to load from config?
	 * Have we already loaded from config?
	 */
	if (!config_available || (global_ints_initialized & key_index))
		return global_ints[key];
	global_ints_initialized |= key_index;

	/* Try getting a boolean value before trying an int. */
	if (git_config_get_maybe_bool(global_int_names[key], &global_ints[key]) < 0)
		git_config_get_int(global_int_names[key], &global_ints[key]);
	return global_ints[key];
}
