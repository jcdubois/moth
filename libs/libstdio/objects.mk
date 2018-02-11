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
# @brief list of objects for printf support.
# */

# Need -Uarm for gcc < 3.x
cpu-cflags += -DTINYPRINTF_DEFINE_TFP_PRINTF=1
cpu-cflags += -DTINYPRINTF_DEFINE_TFP_SPRINTF=0
cpu-cflags += -DTINYPRINTF_OVERRIDE_LIBC=1

common-libs-objs-y += libstdio/tinyprintf.o
