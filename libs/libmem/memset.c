/**
 * Copyright (c) 2017 Jean-Christophe Dubois
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * @file memset.c
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief standalone memset function
 */

#include "types.h"

#include "os_assert.h"

/**
 * fill memory with a constant byte.
 */
void *__memset(void *s, int c, size_t n) {
  os_assert(n > 0);
  os_assert((c >= 0) && (c < 256));
  os_assert(s != NULL);

  char *d = s;

  while (n--) {
    *d++ = c;
  }

  return s;
}

void *memset(void *s, int c, size_t n) {

  static void *(*const __memset_vp)(void *, int, size_t) = (__memset);

  /**
   * we call __memset through a funtion pointer to make sure it
   * is not optimized out in case the result is left untouched after
   * zeroization.
   */
  return (*__memset_vp)(s, c, n);
}
