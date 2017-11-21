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
 * @file 
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief 
 */

#ifndef __MOTH_SPARC_CONTEXT_OFFSET_H__
#define __MOTH_SPARC_CONTEXT_OFFSET_H__

/*
 * registers saved "over" the stack
 * st %xx, [%sp + xx_OFFSET]
 */
#define L0_OFFSET          0x00
#define L1_OFFSET          0x04
#define L2_OFFSET          0x08
#define L3_OFFSET          0x0c
#define L4_OFFSET          0x10
#define L5_OFFSET          0x14
#define L6_OFFSET          0x18
#define L7_OFFSET          0x1c
#define I0_OFFSET          0x20
#define I1_OFFSET          0x24
#define I2_OFFSET          0x28
#define I3_OFFSET          0x2c
#define I4_OFFSET          0x30
#define I5_OFFSET          0x34
#define I6_OFFSET          0x38
#define I7_OFFSET          0x3c

/*
 * others registers are saved "under" the stack
 * st %xx, [%sp - xx_OFFSET]
 */
#define G7_OFFSET          0x04
#define G6_OFFSET          0x08
#define G5_OFFSET          0x0c
#define G4_OFFSET          0x10
#define G3_OFFSET          0x14
#define G2_OFFSET          0x18
#define G1_OFFSET          0x1c

/*
 * next offsets start at -0x40 because there are "Inputs" registers from
 * -0x20 to -0x3c
 */
#define WIM_OFFSET         0x40
#define PSR_OFFSET         0x44
#define Y_OFFSET           0x48
#define PC_OFFSET          0x4c
#define NPC_OFFSET         0x50
#define RESTORE_CNT_OFFSET 0x54

#endif /* !__MOTH_SPARC_CONTEXT_OFFSET_H__ */
