--  Interfaces.C.Extensions -- version bare-metal sparc32
--  Stripped of 128-bit types unsupported on sparc32 target
--  (sparc64-linux-gnu gnatgcc >= 12 introduced 128-bit types
--   incompatible with -m32 / Max_Binary_Modulus = 2**64)
package Interfaces.C.Extensions is
   pragma Pure;

   subtype long_long          is Interfaces.C.long_long;
   subtype unsigned_long_long is Interfaces.C.unsigned_long_long;

end Interfaces.C.Extensions;
