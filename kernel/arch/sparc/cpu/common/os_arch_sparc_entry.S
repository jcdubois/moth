/**
 * Copyright (c) 2017 Jean-Christophe Dubois
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * @file os_arch_sparc_entry.S
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief assembly file for low level trap handling
 */

#include "sparc_conf.h"
#include "sparc_context_offset.h"

# define WIM_INIT      (0x1 << 1)

# define PSR_EC        0x00002000  /* Enable Coprocessor */
# define PSR_EF        0x00001000  /* Enable Floating Point */
# define PSR_S         0x00000080  /* Supervisor */
# define PSR_PS        0x00000040  /* Previous Supervisor */
# define PSR_ET        0x00000020  /* Enable Traps */
# define PSR_CWP_MASK  0x0000001f  /* Current Window Pointer */
# define PSR_PIL(pil)  (((pil)&0xf) << 8) /**< Proc Interrupt Level */
# define PSR_PIL_MASK  PSR_PIL(0xf)

/* Set the function addr for the service and call the trap handler */
/* The "set" instruction is an intrinsic that takes 2 instructions */
# define os_trap_handle(handler)          \
    set handler, %l0;                     \
    b   _os_arch_service_handler;         \
    nop;

/* start kernel */
# define reset_trap_handle()              \
    b   _os_arch_reset_handler;           \
    nop;                                  \
    nop;                                  \
    nop;

/* only branch to special handler */
# define special_trap_handle(handler)     \
    b   handler;                          \
    nop;                                  \
    nop;                                  \
    nop;

/* unexpected trap */
/* keep the trap number, PSR, WIM and call the trap handler */
# define unexpected_trap_handle(trap_nbr) \
    mov %wim, %l0;                        \
    mov %psr, %l3;                        \
    b   _os_arch_error_handler;           \
    mov trap_nbr, %l4;

/* error trap */
/* keep the trap number, PSR, WIM and call the trap handler */
# define error_trap_handle(trap_nbr)      \
    mov %wim, %l0;                        \
    mov %psr, %l3;                        \
    b   _os_arch_error_handler;           \
    mov trap_nbr, %l4;

.section .text.entry, "ax"
.align 4
.global entry
.global _os_arch_trap_vector_table
entry:
_os_arch_trap_vector_table:
    reset_trap_handle()     /* reset */
    error_trap_handle(0x01) /* inst_access_exception */
    error_trap_handle(0x02) /* illegal_instruction */
    error_trap_handle(0x03) /* privileged_instruction */
    error_trap_handle(0x04) /* fp_disabled */
    special_trap_handle(_os_arch_window_overflow_trap_handler)   /* 0x05 window_overflow */
    special_trap_handle(_os_arch_window_underflow_trap_handler)  /* 0x06 window_underflow */
    error_trap_handle(0x07) /* mem_address_not_aligned */
    error_trap_handle(0x08) /* fp_exception */
    error_trap_handle(0x09) /* data_access_exception */
    error_trap_handle(0x0a) /* tag_overflow */
    error_trap_handle(0x0b) /* watchpoint_detected */

    unexpected_trap_handle(0x0c) /* undefined */
    unexpected_trap_handle(0x0d) /* undefined */
    unexpected_trap_handle(0x0e) /* undefined */
    unexpected_trap_handle(0x0f) /* undefined */
    unexpected_trap_handle(0x10) /* undefined */

    /* Interrupt entries */

    unexpected_trap_handle(0x11) /* IRQs */
    unexpected_trap_handle(0x12)
    unexpected_trap_handle(0x13)
    unexpected_trap_handle(0x14)
    unexpected_trap_handle(0x15)
    unexpected_trap_handle(0x16)
    unexpected_trap_handle(0x17)
    unexpected_trap_handle(0x18)
    unexpected_trap_handle(0x19)
    unexpected_trap_handle(0x1a)
    unexpected_trap_handle(0x1b)
    unexpected_trap_handle(0x1c)
    unexpected_trap_handle(0x1d)
    unexpected_trap_handle(0x1e)

    unexpected_trap_handle(0x1f)

    /* Hardware traps */

    error_trap_handle(0x20) /* r_register_access_error */
    error_trap_handle(0x21) /* inst_access_error */
    unexpected_trap_handle(0x22)
    unexpected_trap_handle(0x23)
    error_trap_handle(0x24) /* cp_disabled */
    error_trap_handle(0x25) /* unimplemented_FLUSH */
    unexpected_trap_handle(0x26)
    unexpected_trap_handle(0x27)
    error_trap_handle(0x28) /* cp_exception */
    error_trap_handle(0x29) /* data_access_error */
    error_trap_handle(0x2A) /* division_by_zero */
    error_trap_handle(0x2B) /* data_store_error */
    error_trap_handle(0x2C) /* data_access_MMU_miss */

    unexpected_trap_handle(0x2d)
    unexpected_trap_handle(0x2e)
    unexpected_trap_handle(0x2f)
    unexpected_trap_handle(0x30)
    unexpected_trap_handle(0x31)
    unexpected_trap_handle(0x32)
    unexpected_trap_handle(0x33)
    unexpected_trap_handle(0x34)
    unexpected_trap_handle(0x35)
    unexpected_trap_handle(0x36)
    unexpected_trap_handle(0x37)
    unexpected_trap_handle(0x38)
    unexpected_trap_handle(0x39)
    unexpected_trap_handle(0x3a)
    unexpected_trap_handle(0x3b)

    error_trap_handle(0x3C) /* inst_access_MMU_miss */

    unexpected_trap_handle(0x3d)
    unexpected_trap_handle(0x3e)
    unexpected_trap_handle(0x3f)
    unexpected_trap_handle(0x40)
    unexpected_trap_handle(0x41)
    unexpected_trap_handle(0x42)
    unexpected_trap_handle(0x43)
    unexpected_trap_handle(0x44)
    unexpected_trap_handle(0x45)
    unexpected_trap_handle(0x46)
    unexpected_trap_handle(0x47)
    unexpected_trap_handle(0x48)
    unexpected_trap_handle(0x49)
    unexpected_trap_handle(0x4a)
    unexpected_trap_handle(0x4b)
    unexpected_trap_handle(0x4c)
    unexpected_trap_handle(0x4d)
    unexpected_trap_handle(0x4e)
    unexpected_trap_handle(0x4f)
    unexpected_trap_handle(0x50)
    unexpected_trap_handle(0x51)
    unexpected_trap_handle(0x52)
    unexpected_trap_handle(0x53)
    unexpected_trap_handle(0x54)
    unexpected_trap_handle(0x55)
    unexpected_trap_handle(0x56)
    unexpected_trap_handle(0x57)
    unexpected_trap_handle(0x58)
    unexpected_trap_handle(0x59)
    unexpected_trap_handle(0x5a)
    unexpected_trap_handle(0x5b)
    unexpected_trap_handle(0x5c)
    unexpected_trap_handle(0x5d)
    unexpected_trap_handle(0x5e)
    unexpected_trap_handle(0x5f)
    unexpected_trap_handle(0x60)
    unexpected_trap_handle(0x61)
    unexpected_trap_handle(0x62)
    unexpected_trap_handle(0x63)
    unexpected_trap_handle(0x64)
    unexpected_trap_handle(0x65)
    unexpected_trap_handle(0x66)
    unexpected_trap_handle(0x67)
    unexpected_trap_handle(0x68)
    unexpected_trap_handle(0x69)
    unexpected_trap_handle(0x6a)
    unexpected_trap_handle(0x6b)
    unexpected_trap_handle(0x6c)
    unexpected_trap_handle(0x6d)
    unexpected_trap_handle(0x6e)
    unexpected_trap_handle(0x6f)
    unexpected_trap_handle(0x70)
    unexpected_trap_handle(0x71)
    unexpected_trap_handle(0x72)
    unexpected_trap_handle(0x73)
    unexpected_trap_handle(0x74)
    unexpected_trap_handle(0x75)
    unexpected_trap_handle(0x76)
    unexpected_trap_handle(0x77)
    unexpected_trap_handle(0x78)
    unexpected_trap_handle(0x79)
    unexpected_trap_handle(0x7a)
    unexpected_trap_handle(0x7b)
    unexpected_trap_handle(0x7c)
    unexpected_trap_handle(0x7d)
    unexpected_trap_handle(0x7e)
    unexpected_trap_handle(0x7f)

    /* Software traps */
    os_trap_handle(os_arch_sched_wait)  /* 0x80 = sched_wait()  */
    os_trap_handle(os_arch_sched_yield) /* 0x81 = sched_yield() */
    os_trap_handle(os_arch_mbx_send)    /* 0x82 = mbx_send()    */
    os_trap_handle(os_arch_mbx_receive) /* 0x83 = mbx_receive() */
    os_trap_handle(os_arch_sched_exit)  /* 0x84 = sched_exit() */

    unexpected_trap_handle(0x85)
    unexpected_trap_handle(0x86)
    unexpected_trap_handle(0x87)
    unexpected_trap_handle(0x88)
    unexpected_trap_handle(0x89)
    unexpected_trap_handle(0x8a)
    unexpected_trap_handle(0x8b)
    unexpected_trap_handle(0x8c)
    unexpected_trap_handle(0x8d)
    unexpected_trap_handle(0x8e)
    unexpected_trap_handle(0x8f)
    unexpected_trap_handle(0x90)
    unexpected_trap_handle(0x91)
    unexpected_trap_handle(0x92)
    unexpected_trap_handle(0x93)
    unexpected_trap_handle(0x94)
    unexpected_trap_handle(0x95)
    unexpected_trap_handle(0x96)
    unexpected_trap_handle(0x97)
    unexpected_trap_handle(0x98)
    unexpected_trap_handle(0x99)
    unexpected_trap_handle(0x9a)
    unexpected_trap_handle(0x9b)
    unexpected_trap_handle(0x9c)
    unexpected_trap_handle(0x9d)
    unexpected_trap_handle(0x9e)
    unexpected_trap_handle(0x9f)
    unexpected_trap_handle(0xa0)
    unexpected_trap_handle(0xa1)
    unexpected_trap_handle(0xa2)
    unexpected_trap_handle(0xa3)
    unexpected_trap_handle(0xa4)
    unexpected_trap_handle(0xa5)
    unexpected_trap_handle(0xa6)
    unexpected_trap_handle(0xa7)
    unexpected_trap_handle(0xa8)
    unexpected_trap_handle(0xa9)
    unexpected_trap_handle(0xaa)
    unexpected_trap_handle(0xab)
    unexpected_trap_handle(0xac)
    unexpected_trap_handle(0xad)
    unexpected_trap_handle(0xae)
    unexpected_trap_handle(0xaf)
    unexpected_trap_handle(0xb0)
    unexpected_trap_handle(0xb1)
    unexpected_trap_handle(0xb2)
    unexpected_trap_handle(0xb3)
    unexpected_trap_handle(0xb4)
    unexpected_trap_handle(0xb5)
    unexpected_trap_handle(0xb6)
    unexpected_trap_handle(0xb7)
    unexpected_trap_handle(0xb8)
    unexpected_trap_handle(0xb9)
    unexpected_trap_handle(0xba)
    unexpected_trap_handle(0xbb)
    unexpected_trap_handle(0xbc)
    unexpected_trap_handle(0xbd)
    unexpected_trap_handle(0xbe)
    unexpected_trap_handle(0xbf)
    unexpected_trap_handle(0xc0)
    unexpected_trap_handle(0xc1)
    unexpected_trap_handle(0xc2)
    unexpected_trap_handle(0xc3)
    unexpected_trap_handle(0xc4)
    unexpected_trap_handle(0xc5)
    unexpected_trap_handle(0xc6)
    unexpected_trap_handle(0xc7)
    unexpected_trap_handle(0xc8)
    unexpected_trap_handle(0xc9)
    unexpected_trap_handle(0xca)
    unexpected_trap_handle(0xcb)
    unexpected_trap_handle(0xcc)
    unexpected_trap_handle(0xcd)
    unexpected_trap_handle(0xce)
    unexpected_trap_handle(0xcf)
    unexpected_trap_handle(0xd0)
    unexpected_trap_handle(0xd1)
    unexpected_trap_handle(0xd2)
    unexpected_trap_handle(0xd3)
    unexpected_trap_handle(0xd4)
    unexpected_trap_handle(0xd5)
    unexpected_trap_handle(0xd6)
    unexpected_trap_handle(0xd7)
    unexpected_trap_handle(0xd8)
    unexpected_trap_handle(0xd9)
    unexpected_trap_handle(0xda)
    unexpected_trap_handle(0xdb)
    unexpected_trap_handle(0xdc)
    unexpected_trap_handle(0xdd)
    unexpected_trap_handle(0xde)
    unexpected_trap_handle(0xdf)
    unexpected_trap_handle(0xe0)
    unexpected_trap_handle(0xe1)
    unexpected_trap_handle(0xe2)
    unexpected_trap_handle(0xe3)
    unexpected_trap_handle(0xe4)
    unexpected_trap_handle(0xe5)
    unexpected_trap_handle(0xe6)
    unexpected_trap_handle(0xe7)
    unexpected_trap_handle(0xe8)
    unexpected_trap_handle(0xe9)
    unexpected_trap_handle(0xea)
    unexpected_trap_handle(0xeb)
    unexpected_trap_handle(0xec)
    unexpected_trap_handle(0xed)
    unexpected_trap_handle(0xee)
    unexpected_trap_handle(0xef)
    unexpected_trap_handle(0xf0)
    unexpected_trap_handle(0xf1)
    unexpected_trap_handle(0xf2)
    unexpected_trap_handle(0xf3)
    unexpected_trap_handle(0xf4)
    unexpected_trap_handle(0xf5)
    unexpected_trap_handle(0xf6)
    unexpected_trap_handle(0xf7)
    unexpected_trap_handle(0xf8)
    unexpected_trap_handle(0xf9)
    unexpected_trap_handle(0xfa)
    unexpected_trap_handle(0xfb)
    unexpected_trap_handle(0xfc)
    unexpected_trap_handle(0xfd)
    unexpected_trap_handle(0xfe)
    unexpected_trap_handle(0xff)

.section .text
_os_arch_reset_handler:

    flush

    /* Init IU */

    /* set PSR : Processor State Register */
    /* We are in supervisor state and trap are enabled */
    /* interrupts are disabled */
    set   (PSR_S | PSR_ET | PSR_PIL_MASK), %l0
    mov   %l0, %psr
    nop                           /* delay slot */
    nop
    nop

    /* set TBR : Trap base register */
    set   _os_arch_trap_vector_table, %l0
    mov   %l0, %tbr
    nop                           /* delay slot */
    nop
    nop

    /* clear Y: */
    mov   %g0, %y
    nop                           /* delay slot */
    nop
    nop

    /* clear ASR: */
    mov   %g0, %asr16
    nop                           /* delay slot */
    nop
    nop

    /* clear WIM: */
    mov   %g0, %wim
    nop                           /* delay slot */
    nop
    nop

    /* clear the kernel bss segment */
    set   __bss_begin, %l0
    set   __bss_end, %l1
    clrb  [ %l0 ]

__os_arch_clean_bss_loop:

    inc   %l0
    cmp   %l0, %l1
    bne,a __os_arch_clean_bss_loop
    clrb  [ %l0 ]

    /* clear the kernel stack segment */
    set   __stack_begin, %l0
    set   __stack_end, %l1
    clrb  [ %l0 ]

__os_arch_clean_stack_loop:

    inc   %l0
    cmp   %l0, %l1
    bne,a __os_arch_clean_stack_loop
    clrb  [ %l0 ]

    /* Clean all register windows */
    save                          /* get into the last window */
    mov   %psr, %g1
    restore                       /* return to window #0 */
    and   %g1, PSR_CWP_MASK, %g1

__os_arch_clean_win_loop:

    subcc %g1, 1, %g1
    mov   %g0, %i0
    mov   %g0, %i1
    mov   %g0, %i2
    mov   %g0, %i3
    mov   %g0, %i4
    mov   %g0, %i5
    mov   %g0, %i6
    mov   %g0, %i7
    mov   %g0, %l0
    mov   %g0, %l1
    mov   %g0, %l2
    mov   %g0, %l3
    mov   %g0, %l4
    mov   %g0, %l5
    mov   %g0, %l6
    mov   %g0, %l7
    bg    __os_arch_clean_win_loop
    save

    /* Set WIM: */
    mov   WIM_INIT, %g1
    mov   %g1, %wim
    nop                           /* delay slot */
    nop
    nop

    /* clear global registers. */
    mov   %g0, %g1
    mov   %g0, %g2
    mov   %g0, %g3
    mov   %g0, %g4
    mov   %g0, %g5
    mov   %g0, %g6
    mov   %g0, %g7

    /* set SP : Stack pointer and FP : Frame pointer */
    set   __stack_end, %fp
    andn  %fp, 0x0f, %fp          /* align stack on 16-byte boundary */
    sub   %fp, 0x40, %sp

    call  os_arch_init
    nop                           /* delay slot */

    /* retreive the stack pointer of the current task */
    mov   %o0, %g2

    call  _os_arch_context_restore
    nop                           /* delay slot */

    /*
     *   After context_restore
     *   %l2 = sp
     *   %l3 = pc
     *   %l4 = npc
     */

    /* Disable Traps before ret */
    /* interrupt are kept disabled */
    /* Make sure we will return to user space */
    mov   %psr, %l0
    andn  %l0, (PSR_ET | PSR_PS), %l0
    mov   %l0, %psr
    mov   %g0, %l0                /* clear %l0 */
    nop                           /* delay slot */
    nop

    /* Return from Trap */
    jmpl  %l3, %g0                /* pc */
    rett  %l4                     /* npc */

_os_arch_error_handler:

    /*
     * input:
     *   %l0 = %wim
     *   %l1 = %pc
     *   %l2 = %npc
     *   %l3 = %psr
     *   %l4 = trap_nbr
     */

    sub   %fp, 0x40, %sp

    /* disable interrupts enable traps */
    mov   %psr, %l5
    or    %l5, (PSR_ET | PSR_PIL_MASK), %l5
    mov   %l5, %psr
    nop                           /* delay slot */
    nop
    nop

    call  _os_arch_context_save
    nop                           /* delay slot */
    /* %g6 = restore counter from context_save */

    mov   %fp, %o5                /* stack pointer - 6th arg */

    /* return on kernel stack */
    set   __stack_end, %fp        /* This should already be aligned */
    andn  %fp, 0x0f, %fp          /* align stack on 16-byte boundary */
    sub   %fp, 0x40, %sp          /* move %sp 64 bytes from %fp */

    mov   %l1, %o0                /* %pc - 1st arg */
    mov   %l2, %o1                /* %npc - 2nd arg */
    mov   %l3, %o2                /* %psr - 3rd arg */
    mov   %l4, %o3                /* trap_nbr - 4th arg */
    call  os_arch_error_handler
    mov   %g6, %o4                /* restore counter - 5th arg */
                                  /* We should not return */
    b     .                       /* If we do, we hang there */

_os_arch_service_handler:

    /*
     * input:
     *   %l0 = @ of moth service
     *   %l1 = %pc
     *   %l2 = %npc
     */

    /*
     * As we just get into the trap, the window register moved one slot up
     * and the stack pointer of the "calling" application is now in the
     * frame pointer register.
     * So we update the current stack pointer (from the frame pointer)
     * by making ourself some space (64 bytes) to save our registers.
     */
    sub   %fp, 0x40, %sp

    /* disable interrupts enable traps */
    mov   %psr, %l5
    or    %l5, (PSR_ET | PSR_PIL_MASK), %l5
    mov   %l5, %psr
    nop                           /* delay slot */
    nop
    nop

    call  _os_arch_context_save
    nop                           /* delay slot */
    /* %g6 = restore counter from context_save */

    mov   %fp, %o0                /* stack pointer - 1st arg */

    /* return on kernel stack */
    set   __stack_end, %fp        /* This should already be aligned */
    andn  %fp, 0x0f, %fp          /* align stack on 16-byte boundary */
    sub   %fp, 0x80, %sp          /* move %sp 128 bytes from %fp */

    call  %l0                     /* call the function for os service */
    nop

    /* retreive the stack pointer of the current task */
    mov   %o0, %g2

    /* restore the selected task register set */
    call  _os_arch_context_restore
    nop                           /* delay slot */

    /*
     *   After context_restore
     *   %l2 = sp
     *   %l3 = pc
     *   %l4 = npc
     */

    /* Disable Traps and enable interrupts before ret */
    /* interrupts are kept disabled */
    /* Make sure we will return to user space */
    mov   %psr, %l0
    andn  %l0, (PSR_ET | PSR_PS), %l0
    mov   %l0, %psr
    nop                           /* delay slot */
    nop
    nop

    /* Return from Trap */
    jmpl  %l3, %g0                /* pc */
    rett  %l4                     /* npc */

_os_arch_context_save:

    /*
     * input:
     *   %l0 = @ of service function
     *   %l1 = %pc
     *   %l2 = %npc
     * output:
     *   %g6 = restore counter
     *
     *   little reminder of the register windows concept
     *   CWP = 4
     *   WIM = 0b00000010
     *
     *   Windows:
     *   0 - used
     *   1 - invalid
     *   2 - unused
     *   3 - unused
     *   4 - unused
     *   5 - current
     *   6 - used
     *   7 - used
     *
     *   The 5th window is the trap window.
     *   We have to save all the used windows.
     *   With the "restore" instruction we can
     *   walk through windows until we reach the invalid one.
     */

    /* Disable Traps */
    mov   %psr, %o0
    andn  %o0, PSR_ET, %o0
    mov   %o0, %psr
    nop                           /* delay slot */
    nop
    nop

    /* save the global and input registers "under" the stack */
    st    %g1, [%fp - G1_OFFSET]
    st    %g2, [%fp - G2_OFFSET]
    st    %g3, [%fp - G3_OFFSET]
    st    %g4, [%fp - G4_OFFSET]
    st    %g5, [%fp - G5_OFFSET]
    st    %g6, [%fp - G6_OFFSET]
    st    %g7, [%fp - G7_OFFSET]
    st    %i0, [%fp - I0_OFFSET]
    st    %i1, [%fp - I1_OFFSET]
    st    %i2, [%fp - I2_OFFSET]
    st    %i3, [%fp - I3_OFFSET]
    st    %i4, [%fp - I4_OFFSET]
    st    %i5, [%fp - I5_OFFSET]
    st    %i6, [%fp - I6_OFFSET]
    st    %i7, [%fp - I7_OFFSET]

    and   %o0, PSR_CWP_MASK, %g3  /* %g3 = CWP */
    mov   1, %g2
    sll   %g2, %g3, %g2           /* %g2 = Windows current mask */
    mov   %wim, %g1
    mov   %o7, %g7                /* move return address to g7 */
    clr   %g6                     /* set restore counter to 0 */

__os_arch_save_loop:

    /*  The loop with our example.
     *   00000010 : %g1 WIM
     *   00100000 : %g2 init
     *   01000000 : %g2 1st loop : ok
     *   10000000 : %g2 2nd loop : ok
     *   00000001 : %g2 3rd loop : ok
     *   00000010 : %g2 4th loop : ((%g2 & %g1) != 0) => quit
     */
    sll   %g2, 1, %g4
    srl   %g2, WINDOWS_NBR - 1, %g2
    or    %g2, %g4, %g2           /* nice shift left with modulo :) */

    andcc %g2, %g1, %g0
    bnz   __os_arch_end_of_save_loop
    nop                           /* delay slot */

    /* We still have some register set to save */
    restore

    inc   %g6                     /* increment restore counter */
    /* little optimisation with store double */
    std   %l0, [%sp + L0_OFFSET]
    std   %l2, [%sp + L2_OFFSET]
    std   %l4, [%sp + L4_OFFSET]
    std   %l6, [%sp + L6_OFFSET]

    std   %i0, [%sp + I0_OFFSET]
    std   %i2, [%sp + I2_OFFSET]
    std   %i4, [%sp + I4_OFFSET]

    ba    __os_arch_save_loop
    std   %i6, [%sp + I6_OFFSET]  /* delay slot */

__os_arch_end_of_save_loop:

    /* return in the trap window */
    mov   %psr, %g5
    andn  %g5, PSR_CWP_MASK, %g5  /* clear the CWP */
    or    %g5, %g3, %g5          /* set the CWP saved in %g3 before loop */
    or    %g5, PSR_ET, %g5        /* enable traps */
    mov   %g5, %psr
    nop                           /* delay slot */
    nop
    nop

    /* set new WIM so the trap handler get the maximum number of windows */
    mov   1, %g5
    sll   %g5, %g3, %g5

    sll   %g5, 1, %g1
    srl   %g5, WINDOWS_NBR - 1, %g5
    or    %g5, %g1, %g5
    mov   %g5, %wim

    /* save the others registers "under" the stack */
    st    %l1, [%fp - PC_OFFSET]
    st    %l2, [%fp - NPC_OFFSET]
    st    %g6, [%fp - RESTORE_CNT_OFFSET]

    jmpl  %g7 + 8, %g0            /* return to caller */
    nop                           /* delay slot */

_os_arch_context_restore:

    /*
     *   %g1 = restore counter
     *   %g2 = sp (mov %g2, %fp)
     *   %g3 = pc
     *   %g4 = npc
     *
     *   The goal is to restore the register windows exactly
     *   like there was before the trap.
     *   So we reload the same number of windows.
     *
     *   Example with restore_counter = 4
     *   Windows after restore:
     *   0 - used
     *   1 - used
     *   2 - used
     *   3 - used
     *   4 - invalid
     *   5 - unused
     *   6 - unused
     *   7 - current
     *
     */

    mov   %o7, %g7                /* save return addr */

    /* Disable Traps and set CWP */
    mov   %psr, %l0
    andn  %l0, (PSR_ET | PSR_CWP_MASK), %l0
    or    %l0, WINDOWS_NBR - 1, %l0 /* CWP = 7 */
    mov   %l0, %psr
    nop                           /* delay slot */
    nop
    nop

    mov   %g2, %fp
    ld    [%g2 - RESTORE_CNT_OFFSET], %g1
    ld    [%g2 - PC_OFFSET], %g3
    ld    [%g2 - NPC_OFFSET], %g4

    /* Restore %wim */
    mov   1, %l0
    sll   %l0, %g1 ,%l0
    mov   %l0, %wim
    nop                           /* delay slot */
    nop
    nop

    tst   %g1
    bz    __os_arch_end_of_restore_loop
    nop                           /* delay slot */

__os_arch_restore_loop:

    restore

    /* little optimisation with load double */
    ldd   [%sp + L0_OFFSET], %l0
    ldd   [%sp + L2_OFFSET], %l2
    ldd   [%sp + L4_OFFSET], %l4
    ldd   [%sp + L6_OFFSET], %l6

    ldd   [%sp + I0_OFFSET], %i0
    ldd   [%sp + I2_OFFSET], %i2
    ldd   [%sp + I4_OFFSET], %i4
    ldd   [%sp + I6_OFFSET], %i6

    subcc %g1, 1, %g1
    bnz   __os_arch_restore_loop
    nop                           /* delay slot */

__os_arch_end_of_restore_loop:

    mov   %psr, %g6
    andn  %g6, PSR_CWP_MASK, %g6
    or    %g6, WINDOWS_NBR - 1, %g6 /* CWP = 7 */
    mov   %g6, %psr
    nop                           /* delay slot */
    nop
    nop

    /* save my global registers */
    mov   %g2, %l2                /* sp */
    mov   %g3, %l3                /* pc */
    mov   %g4, %l4                /* npc */
    mov   %g7, %l7                /* return addr */

    /* restore the context's global and input registers */
    ld    [%l2 - G1_OFFSET], %g1
    ld    [%l2 - G2_OFFSET], %g2
    ld    [%l2 - G3_OFFSET], %g3
    ld    [%l2 - G4_OFFSET], %g4
    ld    [%l2 - G5_OFFSET], %g5
    ld    [%l2 - G6_OFFSET], %g6
    ld    [%l2 - G7_OFFSET], %g7
    ld    [%l2 - I0_OFFSET], %i0
    ld    [%l2 - I1_OFFSET], %i1
    ld    [%l2 - I2_OFFSET], %i2
    ld    [%l2 - I3_OFFSET], %i3
    ld    [%l2 - I4_OFFSET], %i4
    ld    [%l2 - I5_OFFSET], %i5
    ld    [%l2 - I6_OFFSET], %i6
    ld    [%l2 - I7_OFFSET], %i7

    mov   %l2, %fp
    jmpl  %l7 + 8, %g0            /* return to caller */
    nop                           /* delay slot */
