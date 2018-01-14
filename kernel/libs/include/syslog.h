#ifndef __SYSLOG_H__
#define __SYSLOG_H__

#if defined(CONFIG_NONE_UART)

/* If there is no console then we can redefine printf() and syslog() */
#define syslog(...)
#define printf(...)

#else // CONFIG_NONE_UART

// For printf support
#include <stdio.h>

#if defined(CONFIG_VERBOSE_MODE)

#define syslog(format, ...) printf(format, ##__VA_ARGS__);

#else //CONFIG_VERBOSE_MODE

#define syslog(...)

#endif // CONFIG_VERBOSE_MODE

#endif // CONFIG_NONE_UART

#endif // __SYSLOG_H__
