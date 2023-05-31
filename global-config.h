#ifndef GLOBAL_CONFIG_H
#define GLOBAL_CONFIG_H

enum int_config_key {
	INT_CONFIG_NONE = 0,
	INT_CONFIG_TRUST_EXECUTABLE_BIT,
	INT_CONFIG_TRUST_CTIME,
	INT_CONFIG_QUOTE_PATH_FULLY,
};

/**
 * During initial process loading, the config system is not quite available.
 * The config global system needs an indicator that the process is ready
 * to read config. Before this method is called, it will return the
 * default values.
 */
void declare_config_available(void);

/**
 * Given a config key (by enum), return its value.
 *
 * If declare_config_available() has not been called, then this returns
 * the default value. Otherwise, it guarantees that the value has been
 * filled from config before returning the value.
 */
int get_int_config_global(enum int_config_key key);

#endif /* GLOBAL_CONFIG_H */
