
#ifndef __MOTH_STRING_H__
#define __MOTH_STRING_H__

#include "types.h"

#ifdef __cplusplus
extern "C" {
#endif

void *memset(void *s, int c, size_t n);
void *memcpy(void *dest, const void *src, size_t n);

#ifdef __cplusplus
}
#endif

#endif // __MOTH_STRING_H__
