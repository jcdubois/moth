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
 * @file entry.S
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief assembly file for low level trap handling
 */

#include "sparc_conf.h"
#include "sparc_context_offset.h"

# define WIM_INIT	(0x1 << 1)

# define PSR_EC		0x00002000  /* Enable Coprocessor */
# define PSR_EF		0x00001000  /* Enable Floating Point */
# define PSR_S		0x00000080  /* Supervisor */
# define PSR_PS		0x00000040  /* Previous Supervisor */
# define PSR_ET		0x00000020  /* Enable Traps */
# define PSR_CWP_MASK	0x0000001f  /* Current Window Pointer */
# define PSR_PIL(pil)	(((pil)&0xf) << 8) /**< Proc Interrupt Level */
# define PSR_PIL_MASK	PSR_PIL(0xf)

/* keep the trap number, PSR, WIM and call the trap handler */
# define trap_handle(trap_nbr)  \
	mov %wim, %l0;		\
	mov %psr, %l3;		\
	b   _os_arch_trap_prehandler;	\
	mov trap_nbr, %l4;

/* start kernel */
# define trap_reset()		\
	b   _os_arch_reset_prehandler;	\
	nop;			\
	nop;			\
	nop;

/* only branch to special handler */
# define trap_special_handle(handler)	\
	b   handler;			\
	nop;				\
	nop;				\
	nop;

/* unhandled trap */
# define unhandled_trap(trap_nbr) trap_reset()

.section .text.entry
.align 4
.global entry
.global _os_arch_trap_vector_table
entry:
_os_arch_trap_vector_table:
	trap_reset()      /* reset */
	trap_handle(0x01) /* inst_access_exception */
	trap_handle(0x02) /* illegal_instruction */
	trap_handle(0x03) /* privileged_instruction */
	trap_handle(0x04) /* fp_disabled */
	trap_special_handle(_os_arch_window_overflow_trap_handler)   /* 0x05 window_overflow */
	trap_special_handle(_os_arch_window_underflow_trap_handler)  /* 0x06 window_underflow */
	trap_handle(0x07) /* mem_address_not_aligned */
	trap_handle(0x08) /* fp_exception */
	trap_handle(0x09) /* data_access_exception */
	trap_handle(0x0a) /* tag_overflow */
	trap_handle(0x0b) /* watchpoint_detected */

	unhandled_trap(0x0c) /* undefined */
	unhandled_trap(0x0d) /* undefined */
	unhandled_trap(0x0e) /* undefined */
	unhandled_trap(0x0f) /* undefined */
	unhandled_trap(0x10) /* undefined */

	/* Interrupt entries */

	trap_handle(0x11) /* IRQs */
	trap_handle(0x12)
	trap_handle(0x13)
	trap_handle(0x14)
	trap_handle(0x15)
	trap_handle(0x16)
	trap_handle(0x17)
	trap_handle(0x18)
	trap_handle(0x19)
	trap_handle(0x1a)
	trap_handle(0x1b)
	trap_handle(0x1c)
	trap_handle(0x1d)
	trap_handle(0x1e)

	unhandled_trap(0x1f)

	/* Hardware traps */

	trap_handle(0x20) /* r_register_access_error */
	trap_handle(0x21) /* inst_access_error */
	trap_handle(0x22)
	trap_handle(0x23)
	trap_handle(0x24) /* cp_disabled */
	trap_handle(0x25) /* unimplemented_FLUSH */
	trap_handle(0x26)
	trap_handle(0x27)
	trap_handle(0x28) /* cp_exception */
	trap_handle(0x29) /* data_access_error */
	trap_handle(0x2A) /* division_by_zero */
	trap_handle(0x2B) /* data_store_error */
	trap_handle(0x2C) /* data_access_MMU_miss */

	unhandled_trap(0x2d)
	unhandled_trap(0x2e)
	unhandled_trap(0x2f)
	unhandled_trap(0x30)
	unhandled_trap(0x31)
	unhandled_trap(0x32)
	unhandled_trap(0x33)
	unhandled_trap(0x34)
	unhandled_trap(0x35)
	unhandled_trap(0x36)
	unhandled_trap(0x37)
	unhandled_trap(0x38)
	unhandled_trap(0x39)
	unhandled_trap(0x3a)
	unhandled_trap(0x3b)

	trap_handle(0x3C) /* inst_access_MMU_miss */

	unhandled_trap(0x3d)
	unhandled_trap(0x3e)
	unhandled_trap(0x3f)
	unhandled_trap(0x40)
	unhandled_trap(0x41)
	unhandled_trap(0x42)
	unhandled_trap(0x43)
	unhandled_trap(0x44)
	unhandled_trap(0x45)
	unhandled_trap(0x46)
	unhandled_trap(0x47)
	unhandled_trap(0x48)
	unhandled_trap(0x49)
	unhandled_trap(0x4a)
	unhandled_trap(0x4b)
	unhandled_trap(0x4c)
	unhandled_trap(0x4d)
	unhandled_trap(0x4e)
	unhandled_trap(0x4f)
	unhandled_trap(0x50)
	unhandled_trap(0x51)
	unhandled_trap(0x52)
	unhandled_trap(0x53)
	unhandled_trap(0x54)
	unhandled_trap(0x55)
	unhandled_trap(0x56)
	unhandled_trap(0x57)
	unhandled_trap(0x58)
	unhandled_trap(0x59)
	unhandled_trap(0x5a)
	unhandled_trap(0x5b)
	unhandled_trap(0x5c)
	unhandled_trap(0x5d)
	unhandled_trap(0x5e)
	unhandled_trap(0x5f)
	unhandled_trap(0x60)
	unhandled_trap(0x61)
	unhandled_trap(0x62)
	unhandled_trap(0x63)
	unhandled_trap(0x64)
	unhandled_trap(0x65)
	unhandled_trap(0x66)
	unhandled_trap(0x67)
	unhandled_trap(0x68)
	unhandled_trap(0x69)
	unhandled_trap(0x6a)
	unhandled_trap(0x6b)
	unhandled_trap(0x6c)
	unhandled_trap(0x6d)
	unhandled_trap(0x6e)
	unhandled_trap(0x6f)
	unhandled_trap(0x70)
	unhandled_trap(0x71)
	unhandled_trap(0x72)
	unhandled_trap(0x73)
	unhandled_trap(0x74)
	unhandled_trap(0x75)
	unhandled_trap(0x76)
	unhandled_trap(0x77)
	unhandled_trap(0x78)
	unhandled_trap(0x79)
	unhandled_trap(0x7a)
	unhandled_trap(0x7b)
	unhandled_trap(0x7c)
	unhandled_trap(0x7d)
	unhandled_trap(0x7e)
	unhandled_trap(0x7f)

	/* Software traps */

	trap_handle(0x80) /* sched_wait()  */
	trap_handle(0x81) /* sched_yield() */
	trap_handle(0x82) /* mbx_send()    */
	trap_handle(0x83) /* mbx_receive() */
	trap_handle(0x84) /* exit() */

	unhandled_trap(0x85)
	unhandled_trap(0x86)
	unhandled_trap(0x87)
	unhandled_trap(0x88)
	unhandled_trap(0x89)
	unhandled_trap(0x8a)
	unhandled_trap(0x8b)
	unhandled_trap(0x8c)
	unhandled_trap(0x8d)
	unhandled_trap(0x8e)
	unhandled_trap(0x8f)
	unhandled_trap(0x90)
	unhandled_trap(0x91)
	unhandled_trap(0x92)
	unhandled_trap(0x93)
	unhandled_trap(0x94)
	unhandled_trap(0x95)
	unhandled_trap(0x96)
	unhandled_trap(0x97)
	unhandled_trap(0x98)
	unhandled_trap(0x99)
	unhandled_trap(0x9a)
	unhandled_trap(0x9b)
	unhandled_trap(0x9c)
	unhandled_trap(0x9d)
	unhandled_trap(0x9e)
	unhandled_trap(0x9f)
	unhandled_trap(0xa0)
	unhandled_trap(0xa1)
	unhandled_trap(0xa2)
	unhandled_trap(0xa3)
	unhandled_trap(0xa4)
	unhandled_trap(0xa5)
	unhandled_trap(0xa6)
	unhandled_trap(0xa7)
	unhandled_trap(0xa8)
	unhandled_trap(0xa9)
	unhandled_trap(0xaa)
	unhandled_trap(0xab)
	unhandled_trap(0xac)
	unhandled_trap(0xad)
	unhandled_trap(0xae)
	unhandled_trap(0xaf)
	unhandled_trap(0xb0)
	unhandled_trap(0xb1)
	unhandled_trap(0xb2)
	unhandled_trap(0xb3)
	unhandled_trap(0xb4)
	unhandled_trap(0xb5)
	unhandled_trap(0xb6)
	unhandled_trap(0xb7)
	unhandled_trap(0xb8)
	unhandled_trap(0xb9)
	unhandled_trap(0xba)
	unhandled_trap(0xbb)
	unhandled_trap(0xbc)
	unhandled_trap(0xbd)
	unhandled_trap(0xbe)
	unhandled_trap(0xbf)
	unhandled_trap(0xc0)
	unhandled_trap(0xc1)
	unhandled_trap(0xc2)
	unhandled_trap(0xc3)
	unhandled_trap(0xc4)
	unhandled_trap(0xc5)
	unhandled_trap(0xc6)
	unhandled_trap(0xc7)
	unhandled_trap(0xc8)
	unhandled_trap(0xc9)
	unhandled_trap(0xca)
	unhandled_trap(0xcb)	
	unhandled_trap(0xcc)
	unhandled_trap(0xcd)
	unhandled_trap(0xce)
	unhandled_trap(0xcf)
	unhandled_trap(0xd0)
	unhandled_trap(0xd1)
	unhandled_trap(0xd2)
	unhandled_trap(0xd3)
	unhandled_trap(0xd4)
	unhandled_trap(0xd5)
	unhandled_trap(0xd6)
	unhandled_trap(0xd7)
	unhandled_trap(0xd8)
	unhandled_trap(0xd9)
	unhandled_trap(0xda)
	unhandled_trap(0xdb)
	unhandled_trap(0xdc)
	unhandled_trap(0xdd)
	unhandled_trap(0xde)
	unhandled_trap(0xdf)
	unhandled_trap(0xe0)
	unhandled_trap(0xe1)
	unhandled_trap(0xe2)
	unhandled_trap(0xe3)
	unhandled_trap(0xe4)
	unhandled_trap(0xe5)
	unhandled_trap(0xe6)
	unhandled_trap(0xe7)
	unhandled_trap(0xe8)
	unhandled_trap(0xe9)
	unhandled_trap(0xea)
	unhandled_trap(0xeb)
	unhandled_trap(0xec)
	unhandled_trap(0xed)
	unhandled_trap(0xee)
	unhandled_trap(0xef)
	unhandled_trap(0xf0)
	unhandled_trap(0xf1)
	unhandled_trap(0xf2)
	unhandled_trap(0xf3)
	unhandled_trap(0xf4)
	unhandled_trap(0xf5)
	unhandled_trap(0xf6)
	unhandled_trap(0xf7)
	unhandled_trap(0xf8)
	unhandled_trap(0xf9)
	unhandled_trap(0xfa)
	unhandled_trap(0xfb)
	unhandled_trap(0xfc)
	unhandled_trap(0xfd)
	unhandled_trap(0xfe)
	unhandled_trap(0xff)

.section .text
_os_arch_reset_prehandler:

	flush

	/* Init IU */

	/* set PSR : Processor State Register */
	/* We are in supervisor state and trap are anabled */
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

	call  os_init
	nop                           /* delay slot */

	/* retreive the stack pointer of the current task */
	set   os_arch_stack_pointer, %g6
	ld    [%g6], %g2

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

_os_arch_trap_prehandler:

	/*
	 * input:
	 *   %l0 = %wim
	 *   %l1 = %pc
	 *   %l2 = %npc
	 *   %l3 = %psr
	 *   %l4 = trap_nbr
	 */

	/*
	 * As we just get into the trap, the window register moved one slot up
	 * and the stack pointer of the "calling" application is now in the
	 * frame pointer register.
	 * So we update the current stack pointer (from the frame pointer)
	 * by making ourself some space to save our registers.
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

	mov   %fp, %l5

	/* return on kernel stack */
	set   __stack_end, %fp        /* This should already be aligned */
	andn  %fp, 0x0f, %fp          /* align stack on 16-byte boundary */
	sub   %fp, 0x80, %sp          /* move %sp 64 bytes from %fp */

	mov   %l1, %o0                /* %pc - 1st arg */
	mov   %l2, %o1                /* %npc - 2nd arg */
	mov   %l3, %o2                /* %psr - 3rd arg */
	mov   %l4, %o3                /* trap_nbr - 4th arg */
	mov   %g6, %o4                /* restore counter - 5th arg */
	call  os_arch_trap_handler
	mov   %l5, %o5                /* stack pointer - 6th arg */

	/* retreive the stack pointer of the current task */
	set   os_arch_stack_pointer, %g6
	ld    [%g6], %g2

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
	 *   %l0 = %wim
	 *   %l1 = %pc
	 *   %l2 = %npc
	 *   %l3 = %psr
	 *   %l4 = trap_nbr
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
	or    %g5, %g3, %g5	      /* set the CWP saved in %g3 before loop */
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
