#ifndef __SYSLOG_H__
#define __SYSLOG_H__

#if defined(CONFIG_VERBOSE_MODE)

// For printf support
#include <tinyprintf.h>

#define openlog(arg1) init_printf(NULL, arg1)
#define syslog(format, ...) tfp_printf(format, ##__VA_ARGS__);
#define closelog(...)

#else //CONFIG_VERBOSE_MODE

#define openlog(...)
#define syslog(...)
#define closelog(...)

#endif // CONFIG_VERBOSE_MODE

#endif // __SYSLOG_H__
