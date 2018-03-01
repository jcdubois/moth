/**
 * Copyright (c) 2011 Anup Patel.
 * Copyright (c) 2012 Jean-Christophe Dubois.
 * Copyright (c) 2012 Sukanto Ghosh
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
 * @file cpu_entry.S
 * @author Anup Patel (anup@brainfault.org)
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @author Sukanto Ghosh (sukantoghosh@gmail.com)
 * @brief various entry points (booting, reset, exceptions) to xvisor
 */

#include <cpu_defines.h>

	/* 
	 * _start: Primary CPU startup code
	 * _start_secondary_nopen: Secondary CPU startup code without holding pen
	 *
	 * Note: Xvisor could be loaded any where in memory by boot loaders.
	 * The _start ensures that Xvisor executes from intended base address 
	 * provided at compile time.
	 */

.section .text.entry, "ax", %progbits

.globl entry
.globl _os_arch_trap_vector_table
entry:
_os_arch_trap_vector_table:
#if 0
	ldr   pc, __os_arch_reset
	ldr   pc, __os_arch_undefined_instruction
        ldr   pc, __os_arch_software_interrupt
        ldr   pc, __os_arch_prefetch_abort
        ldr   pc, __os_arch_data_abort
        ldr   pc, __os_arch_not_used
        ldr   pc, __os_arch_irq
        ldr   pc, __os_arch_fiq

__os_arch_reset:
	.word _os_arch_reset
__os_arch_undefined_instruction:
	.word _os_arch_undefined_instruction
__os_arch_software_interrupt:
	.word _os_arch_software_interrupt
__os_arch_prefetch_abort:
	.word _os_arch_prefetch_abort
__os_arch_data_abort:
	.word _os_arch_data_abort
__os_arch_not_used:
	.word _os_arch_not_used
__os_arch_irq:
	.word _os_arch_irq
__os_arch_fiq:
	.word _os_arch_fiq
#else
	b	_os_arch_reset
	b	_os_arch_undefined_instruction
	b	_os_arch_software_interrupt
	b	_os_arch_prefetch_abort
	b	_os_arch_data_abort
	b	_os_arch_not_used
	b	_os_arch_irq
	b	_os_arch_fiq
#endif

_os_arch_reset:
	/*
	 * disable interrupts (FIQ and IRQ), also set the cpu to SVC32 mode,
	 * except if in HYP mode already
	 */
	mrs   r0, cpsr				// read CPSR
	and   r1, r0, #CPSR_MODE_MASK		// mask mod bits
	teq   r1, #CPSR_MODE_HYPERVISOR		// test for HYP mode
	bicne r0, r0, #CPSR_MODE_MASK		// clear all mode bits
	orrne r0, r0, #CPSR_MODE_SUPERVISOR	// set SVC mode
	orr   r0, r0, #CPSR_IRQ_DISABLED	// disable IRQ
	orr   r0, r0, #CPSR_FIQ_DISABLED	// disable FIQ
	msr   cpsr,r0				// write CPSR

	/*
	 * Set V=0 in CP15 SCTLR
	 */
	mrc   p15, 0, r0, c1, c0, 0	// read CP15 SCTLR Register
	bic   r0, #SCTLR_V_MASK		// V = 0
	mcr   p15, 0, r0, c1, c0, 0	// write CP15 SCTLR Register

	/*
	 * Set VBAR to point to vector
	 */
	ldr   r0, =_os_arch_trap_vector_table
	mcr   p15, 0, r0, c12, c0, 0	// Set VBAR

	mov	r0, #0
	/* clear the kernel bss segment */
	ldr	r1, =__bss_begin
	ldr	r2, =__bss_end

__os_arch_clean_bss_loop:

	str	r0, [r1], #4
	cmp	r1, r2
	blt	__os_arch_clean_bss_loop

	/* clear the kernel stack segments */
	ldr	r1, =__svc_stack_begin
	ldr	r2, =__svc_stack_end

__os_arch_clean_svc_stack_loop:

	str	r0, [r1], #4
	cmp	r1, r2
	blt	__os_arch_clean_svc_stack_loop

	ldr	r1, =__und_stack_begin
	ldr	r2, =__und_stack_end

__os_arch_clean_und_stack_loop:

	str	r0, [r1], #4
	cmp	r1, r2
	blt	__os_arch_clean_und_stack_loop

	ldr	r1, =__abt_stack_begin
	ldr	r2, =__abt_stack_end

__os_arch_clean_abt_stack_loop:

	str	r0, [r1], #4
	cmp	r1, r2
	blt	__os_arch_clean_abt_stack_loop

	ldr	r1, =__irq_stack_begin
	ldr	r2, =__irq_stack_end

__os_arch_clean_irq_stack_loop:

	str	r0, [r1], #4
	cmp	r1, r2
	blt	__os_arch_clean_irq_stack_loop

	ldr	r1, =__fiq_stack_begin
	ldr	r2, =__fiq_stack_end

__os_arch_clean_fiq_stack_loop:

	str	r0, [r1], #4
	cmp	r1, r2
	blt	__os_arch_clean_fiq_stack_loop

	/* Set Undefined Mode Stack */
	cps	#CPSR_MODE_UNDEFINED
	ldr	sp, =__und_stack_end

	/* Set Abort Mode Stack */
	cps	#CPSR_MODE_ABORT
	ldr	sp, =__abt_stack_end

	/* Set IRQ Mode Stack */
	cps	#CPSR_MODE_IRQ
	ldr	sp, =__irq_stack_end

	/* Set FIQ Mode Stack */
	cps	#CPSR_MODE_FIQ
	ldr	sp, =__fiq_stack_end

	/* Set Supervisor Mode Stack */
	cps	#CPSR_MODE_SUPERVISOR
	ldr	sp, =__svc_stack_end

	/* Call OS init function */
	bl	os_init

	/* We should never reach here. */
	b	.

	/*
	 * Helper Macros for Exception Handlers
	 */
.macro EXCEPTION_HANDLER irqname, lroffset
	.align 5
\irqname:
	sub	lr, lr, #\lroffset;
.endm

/* Save arch registers into small mode-specific stack */
.macro PUSH_REGS mode=CPSR_MODE_SUPERVISOR
	/* Save return address and return machine state */
	.if \mode != CPSR_MODE_SUPERVISOR
		/* Temporary save return address, machine state, R0 and R1 */
		str	lr, [sp, #-4];
		mrs	lr, spsr_all;
		str	lr, [sp, #-8];
		str	r1, [sp, #-12];
		str	r0, [sp, #-16];
		/* Point R0 to temporary location */
		mov	r0, sp
		cps	#CPSR_MODE_SUPERVISOR;
		/* Save return address (i.e. return PC) */
		ldr	r1, [r0, #-4];
		str	r1, [sp, #-4]!;
		/* Save return machine state and decrement stack pointer */
		ldr	r1, [r0, #-8];
		str	r1, [sp, #-(4*16)];
		/* Restore R0, R1 register */
		ldr	r1, [r0, #-12];
		ldr	r0, [r0, #-16];
	.else
		/* Save return address (i.e. return PC) */
		str	lr, [sp, #-4]!;
		/* Save return machine state and decrement stack pointer */
		mrs	lr, spsr_all;
		str	lr, [sp, #-(4*16)];
	.endif

	/* Save r0, r1, ..., r14 and decrement stack pointer */
	stmdb	sp, {r0-r14}^;
	sub	sp, sp, #(4*16);

	/* If we came from privildeged (or non-usr) mode then
	 * overwrite r13, r14 with mode specific banked values
	 * else skip this step
	 */
	ldr	r4, [sp];
	and	r0, r4, #CPSR_MODE_MASK;
	cmp	r0, #CPSR_MODE_USER;
	beq	100f;
	cmp	r0, #CPSR_MODE_SUPERVISOR;
	beq	101f;

	/* We handle all exceptions, irqs, and fiqs in SVC mode so,
	 * should never reach here. Just sit in infinite loop !!!!! 
	 */
	b	.;

	/* Came from svc mode */
101:	add	r1, sp, #(4*17);
	str	r1, [sp, #(4*14)];
	str	lr, [sp, #(4*15)];

	/* Came from usr mode */
100:	add	r1, sp, #(4*17);
	str	r1, [sp, #-4]!;
	mov	r0, sp;
.endm

/* Call C function to handle exception */
.macro CALL_EXCEPTION_CFUNC cfunc
	bl	\cfunc;
.endm

/* Restore registers from arch registers */
.macro PULL_REGS mode=CPSR_MODE_SUPERVISOR
	/* Get arch register pointer.
	 * r12 -> pointer to arch regs
	 */
	mov	r12, sp;

	/* Restore exception stack */ 
	ldr	sp, [r12], #4;

	/* Restore target CPSR */
	ldr	r1, [r12], #4;
	msr	spsr_cxsf, r1;

	/* If-else ladder for different target modes  */
	and	r0, r1, #CPSR_MODE_MASK;
	cmp	r0, #CPSR_MODE_USER;
	beq	200f;
	cmp	r0, #CPSR_MODE_SUPERVISOR;
	beq	201f;

	/* We handle all exceptions, irqs, and fiqs in SVC mode so,
	 * should never reach here. Just sit in infinite loop !!!!! 
	 */
	b	.;

	/* Going back to usr mode */
200:	ldr	lr, [r12, #(4*15)];
	ldmia	r12, {r0-r14}^;
	movs	pc, lr

	/* Going back to svc mode */
201:	ldm	r12, {r0-r15}^;
	mov	r0, r0;
.endm

	/*
	 * Undefined instruction exception handler.
	 */
EXCEPTION_HANDLER _os_arch_undefined_instruction, 4
	PUSH_REGS CPSR_MODE_UNDEFINED
	CALL_EXCEPTION_CFUNC os_arch_undefined_instruction
	PULL_REGS CPSR_MODE_UNDEFINED

	/*
	 * Software interrupt exception handler.
	 */
EXCEPTION_HANDLER _os_arch_software_interrupt, 4
	PUSH_REGS 
	CALL_EXCEPTION_CFUNC os_arch_software_interrupt
	PULL_REGS 

	/*
	 * Prefetch abort exception handler.
	 */
EXCEPTION_HANDLER _os_arch_prefetch_abort, 4
	PUSH_REGS CPSR_MODE_ABORT
	CALL_EXCEPTION_CFUNC os_arch_prefetch_abort
	PULL_REGS CPSR_MODE_ABORT

	/*
	 * Data abort exception handler.
	 */
EXCEPTION_HANDLER _os_arch_data_abort, 8
	PUSH_REGS CPSR_MODE_ABORT
	CALL_EXCEPTION_CFUNC os_arch_data_abort
	PULL_REGS CPSR_MODE_ABORT

	/*
	 * Not used exception handler.
	 */
EXCEPTION_HANDLER _os_arch_not_used, 4
	PUSH_REGS 
	CALL_EXCEPTION_CFUNC os_arch_not_used
	PULL_REGS 

	/*
	 * IRQ exception handler.
	 */
EXCEPTION_HANDLER _os_arch_irq, 4
	PUSH_REGS CPSR_MODE_IRQ
	CALL_EXCEPTION_CFUNC os_arch_irq
	PULL_REGS CPSR_MODE_IRQ

	/*
	 * FIQ exception handler.
	 */
EXCEPTION_HANDLER _os_arch_fiq, 4
	PUSH_REGS CPSR_MODE_FIQ
	CALL_EXCEPTION_CFUNC os_arch_fiq
	PULL_REGS CPSR_MODE_FIQ

