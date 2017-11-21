/**
 * Memory related functions required for gcc support
 */

#include "os_assert.h"
#include "types.h"

/**
 * fill memory with a constant byte.
 */
void *memset(void *s, int c, size_t n) {
  os_assert(n > 0);
  os_assert((c >= 0) && (c < 256));
  os_assert(s != NULL);

  char *d = s;

  while (n--) {
    *d++ = c;
  }

  return s;
}
