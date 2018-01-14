#/**
# Copyright (c) 2010 Anup Patel.
# All rights reserved.
#
# Copyright (C) 2014 Institut de Recherche Technologique SystemX and OpenWide.
# Modified by Jimmy Durand Wesolowski <jimmy.durand-wesolowski@openwide.fr>
# to improve the device tree dependency generation, and to port the Linux
# device tree source preprocessing rule.
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
# @file rules.mk
# @author Anup Patel (anup@brainfault.org)
# @brief Rules to build & use tools
# */

$(build_dir)/%.dep: $(src_dir)/%.data
	$(V)mkdir -p `dirname $@`
	$(if $(V), @echo " (d2c-dep)   $(subst $(build_dir)/,,$@)")
	$(V)echo "$(@:.dep=.c): $<" > $@
	$(V)echo "$(@:.dep=.o): $(@:.dep=.c)" >> $@

$(build_dir)/%.c: $(src_dir)/%.data
	$(V)mkdir -p `dirname $@`
	$(if $(V), @echo " (d2c)       $(subst $(build_dir)/,,$@)")
	$(V)$(src_dir)/tools/scripts/d2c.py $(subst $(src_dir)/,,$<) > $@

$(build_dir)/%.dep: $(build_dir)/%.data
	$(V)mkdir -p `dirname $@`
	$(if $(V), @echo " (d2c-dep)   $(subst $(build_dir)/,,$@)")
	$(V)echo "$(@:.dep=.c): $<" > $@
	$(V)echo "$(@:.dep=.o): $(@:.dep=.c)" >> $@

$(build_dir)/%.c: $(build_dir)/%.data
	$(V)mkdir -p `dirname $@`
	$(if $(V), @echo " (d2c)       $(subst $(build_dir)/,,$@)")
	$(V)(cd $(build_dir) && $(src_dir)/tools/scripts/d2c.py $(subst $(build_dir)/,,$<) > $@ && cd $(src_dir))
