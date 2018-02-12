/*
 * __aeabi_uidiv.c for 32-bit unsigned integer divide.
 */

/*
 * 32-bit. (internal funtion)
 */
static unsigned int __udivmodsi4(unsigned int num, unsigned int den,
                                 unsigned int *rem_p) {
  unsigned int quot = 0, qbit = 1;

  if (den == 0) {
    return 0;
  }

  /*
   * left-justify denominator and count shift
   */
  while ((signed int)den >= 0) {
    den <<= 1;
    qbit <<= 1;
  }

  while (qbit) {
    if (den <= num) {
      num -= den;
      quot += qbit;
    }
    den >>= 1;
    qbit >>= 1;
  }

  if (rem_p) {
    *rem_p = num;
  }

  return quot;
}

/*
 * 32-bit unsigned integer divide.
 */
unsigned int __aeabi_uidiv(unsigned int num, unsigned int den) {
  return __udivmodsi4(num, den, 0);
}
