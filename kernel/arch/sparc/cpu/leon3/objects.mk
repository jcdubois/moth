#/**
# Copyright (c) 2017 Jean-Christophe Dubois.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# @file objects.mk
# @author Jean-Christophe Dubois (jcd@tribudubois.net)
# @brief list of leon specific objects.
# */

arch-$(CONFIG_ARCH_SPARC) += -m32 
arch-$(CONFIG_ARCH_SPARC) += -mcpu=leon3
#arch-$(CONFIG_ARCH_SPARC) += -mtune=leon3

# Need -Uarm for gcc < 3.x
cpu-cflags += $(arch-y) $(tune-y)
cpu-cflags += -msoft-float
cpu-cflags += -fno-strict-aliasing
cpu-cflags += -mno-fpu
cpu-cflags += -mno-v8plus
cpu-cflags += -Wa,-Av8
cpu-cflags += -Os
cpu-asflags += $(arch-y) $(tune-y)
cpu-asflags += -Wa,-Av8
cpu-ldflags += $(arch-y)
cpu-ldflags += -msoft-float
cpu-ldflags += -mno-v8plus
cpu-mergeflags += -m elf32_sparc

cpu-objs-y += os_arch_cons.o
cpu-objs-y += os_arch_leon.o
cpu-objs-y += os_arch_space.o
cpu-objs-y += mmugen.o

