/**
 * Memory related functions required for gcc support
 */

#include "os_assert.h"
#include "types.h"

/**
 * copy memory area.
 */
void *memcpy(void *dest, const void *src, size_t n) {
  os_assert(n > 0);
  os_assert(dest != NULL);
  os_assert(src != NULL);

  char *d = dest;
  const char *s = src;

  while (n--) {
    *d++ = *s++;
  }
  return dest;
}
