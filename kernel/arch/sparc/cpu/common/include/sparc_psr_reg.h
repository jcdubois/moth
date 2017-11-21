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

#ifndef __MOTH_SPARC_PSR_REG_H__
#define __MOTH_SPARC_PSR_REG_H__

# define PSR_EC		0x00002000  /* Enable Coprocessor */
# define PSR_EF		0x00001000  /* Enable Floating Point */
# define PSR_S		0x00000080  /* Supervisor */
# define PSR_PS		0x00000040  /* Previous Supervisor */
# define PSR_ET		0x00000020  /* Enable Traps */
# define PSR_CWP_MASK	0x0000001f  /* Current Window Pointer */
# define PSR_PIL(pil)	(((pil)&0xf) << 8) /**< Proc Interrupt Level */
# define PSR_PIL_MASK	PSR_PIL(0xf)

#endif /* __MOTH_SPARC_PSR_REG_H__ */
