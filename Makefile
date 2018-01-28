#/**
# Copyright (c) 2017 Jean-Christophe Dubois
# All rights reserved.
#
# Copyright (C) 2014 Institut de Recherche Technologique SystemX and OpenWide.
# Modified by Jimmy Durand Wesolowski <jimmy.durand-wesolowski@openwide.fr>
# to improve the device tree dependency generation.
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
# @file Makefile
# @author Jean-Christophe Dubois (jcd@tribudubois.net)
# @brief toplevel makefile to build MOTH source code
# */

# Current Version
MAJOR = 0
MINOR = 0
RELEASE = 1

# Select Make Options:
# o  Do not use make's built-in rules and variables
# o  Do not print "Entering directory ...";
MAKEFLAGS += -rR --no-print-directory

# Find out source & build directories
src_dir=$(CURDIR)
ifdef O
 build_dir=$(shell readlink -f $(O))
else
 build_dir=$(CURDIR)/build
endif
ifeq ($(build_dir),$(CURDIR))
$(error Build directory is same as source directory.)
endif

# Check if verbosity is ON for build process
VERBOSE_DEFAULT    := 0
CMD_PREFIX_DEFAULT := @
ifdef VERBOSE
	ifeq ("$(origin VERBOSE)", "command line")
		VB := $(VERBOSE)
	else
		VB := $(VERBOSE_DEFAULT)
	endif
else
	VB := $(VERBOSE_DEFAULT)
endif
ifeq ($(VB), 1)
	override V :=
else
	override V := $(CMD_PREFIX_DEFAULT)
endif

# Name & Version
export PROJECT_NAME = MOTH
export PROJECT_VERSION = $(MAJOR).$(MINOR).$(RELEASE)
export CONFIG_DIR=$(build_dir)/openconf
export CONFIG_FILE=$(CONFIG_DIR)/.config

# Openconf settings
export OPENCONF_PROJECT = $(PROJECT_NAME)
export OPENCONF_VERSION = $(PROJECT_VERSION)
export OPENCONF_INPUT = openconf.cfg
export OPENCONF_CONFIG = $(CONFIG_FILE)
export OPENCONF_TMPDIR = $(CONFIG_DIR)
export OPENCONF_AUTOCONFIG = openconf.conf
export OPENCONF_AUTOHEADER = openconf.h

# Include configuration file if present
-include $(CONFIG_FILE)
CONFIG_ARCH:=$(shell echo $(CONFIG_ARCH))
CONFIG_CPU:=$(shell echo $(CONFIG_CPU))
CONFIG_BOARD:=$(shell echo $(CONFIG_BOARD))

# Setup path of directories
export arch_dir=$(CURDIR)/kernel/arch
export cpu_dir=$(arch_dir)/$(CONFIG_ARCH)/cpu/$(CONFIG_CPU)
export cpu_common_dir=$(arch_dir)/$(CONFIG_ARCH)/cpu/common
export board_dir=$(arch_dir)/$(CONFIG_ARCH)/board/$(CONFIG_BOARD)
export board_device_dir=$(arch_dir)/$(CONFIG_ARCH)/board/device
export tools_dir=$(CURDIR)/tools
export core_dir=$(CURDIR)/kernel/core
export kernel_libs_dir=$(CURDIR)/kernel/libs
export common_libs_dir=$(CURDIR)/libs
export apps_dir=$(CURDIR)/apps
export apps_libs_dir=$(apps_dir)/libs
export xsl_arch_dir=$(tools_dir)/xsl/$(CONFIG_ARCH)
export xsl_common_dir=$(tools_dir)/xsl/common

# Setup list of tools for compilation
include $(tools_dir)/tools.mk

# Setup list of targets for compilation
targets-y+=$(build_dir)/system.map
targets-y+=$(build_dir)/moth.elf
targets-y+=$(build_dir)/moth.bin

# Setup compilation environment
cpp=$(CROSS_COMPILE)cpp
cppflags=-include $(OPENCONF_TMPDIR)/$(OPENCONF_AUTOHEADER)
cppflags+=-include $(core_dir)/include/os_openconf.h
cppflags+=-DCONFIG_MAJOR=$(MAJOR)
cppflags+=-DCONFIG_MINOR=$(MINOR)
cppflags+=-DCONFIG_RELEASE=$(RELEASE)
cppflags+=-I$(cpu_dir)/include
cppflags+=-I$(cpu_common_dir)/include
cppflags+=-I$(board_dir)/include
cppflags+=-I$(board_device_dir)/include
cppflags+=-I$(core_dir)/include
cppflags+=-I$(apps_dir)/include
cppflags+=-I$(kernel_libs_dir)/include
cppflags+=-I$(common_libs_dir)/include
cppflags+=-I$(apps_libs_dir)/include
cppflags+=-I$(apps_libs_dir)/include/arch/$(CONFIG_ARCH)
cppflags+=-I$(arch_dir)/include
cppflags+=-I$(build_dir)
cppflags+=$(cpu-cppflags)
cppflags+=$(board-cppflags)
cppflags+=$(libs-cppflags-y)
cc=$(CROSS_COMPILE)gcc
cflags=-g -Wall -Wextra -nostdlib -fno-builtin -nostdinc
cflags+=-Os 
cflags+=$(board-cflags) 
cflags+=$(cpu-cflags) 
cflags+=$(libs-cflags-y) 
cflags+=$(cppflags)
ifdef CONFIG_PROFILE
cflags+=-finstrument-functions
endif
as=$(CROSS_COMPILE)gcc
asflags=-g -Wall -nostdlib -D__ASSEMBLY__ 
asflags+=$(board-asflags) 
asflags+=$(cpu-asflags) 
asflags+=$(libs-asflags-y) 
asflags+=$(cppflags)
ar=$(CROSS_COMPILE)ar
arflags=rcs
ld=$(CROSS_COMPILE)gcc
ldflags=-g -Wall -nostdlib -Wl,--build-id=none
ldflags+=$(board-ldflags) 
ldflags+=$(cpu-ldflags) 
ldflags+=$(libs-ldflags-y) 
merge=$(CROSS_COMPILE)ld
mergeflags=-r
mergeflags+=$(cpu-mergeflags)
data=$(CROSS_COMPILE)ld
dataflags=-r -b binary
objcopy=$(CROSS_COMPILE)objcopy
objdump=$(CROSS_COMPILE)objdump
nm=$(CROSS_COMPILE)nm
ar=$(CROSS_COMPILE)ar
xsl=xsltproc

# Setup functions for compilation
merge_objs = $(V)mkdir -p `dirname $(1)`; \
	     echo " (merge)     $(subst $(build_dir)/,,$(1))"; \
	     $(merge) $(mergeflags) $(2) -o $(1)
merge_deps = $(V)mkdir -p `dirname $(1)`; \
	     echo " (merge-dep) $(subst $(build_dir)/,,$(1))"; \
	     cat $(2) > $(1)
copy_file =  $(V)mkdir -p `dirname $(1)`; \
	     echo " (copy)      $(subst $(build_dir)/,,$(1))"; \
	     cp -f $(2) $(1)
compile_cpp = $(V)mkdir -p `dirname $(1)`; \
	     echo " (cpp)       $(subst $(build_dir)/,,$(1))"; \
	     $(cpp) $(cppflags) $(2) | grep -v "\#" > $(1)
compile_cc_dep = $(V)mkdir -p `dirname $(1)`; \
	     echo " (cc-dep)    $(subst $(build_dir)/,,$(1))"; \
	     echo -n `dirname $(1)`/ > $(1) && \
	     $(cc) $(cflags) $(call dynamic_flags,$(1),$(2))   \
	       -MM $(2) >> $(1) || rm -f $(1)
compile_cc = $(V)mkdir -p `dirname $(1)`; \
	     echo " (cc)        $(subst $(build_dir)/,,$(1))"; \
	     $(cc) $(cflags) $(call dynamic_flags,$(1),$<) -c $(2) -o $(1)
compile_as_dep = $(V)mkdir -p `dirname $(1)`; \
	     echo " (as-dep)    $(subst $(build_dir)/,,$(1))"; \
	     echo -n `dirname $(1)`/ > $(1) && \
	     $(as) $(asflags) $(call dynamic_flags,$(1),$(2))  \
	       -MM $(2) >> $(1) || rm -f $(1)
compile_as = $(V)mkdir -p `dirname $(1)`; \
	     echo " (as)        $(subst $(build_dir)/,,$(1))"; \
	     $(as) $(asflags) $(call dynamic_flags,$(1),$<) -c $(2) -o $(1)
compile_ld = $(V)mkdir -p `dirname $(1)`; \
	     echo " (ld)        $(subst $(build_dir)/,,$(1))"; \
	     $(ld) $(3) $(ldflags) -Wl,-T$(2) -o $(1)
compile_nm = $(V)mkdir -p `dirname $(1)`; \
	     echo " (nm)        $(subst $(build_dir)/,,$(1))"; \
	     $(nm) -n $(2) | grep -v '\( [aNUw] \)\|\(__crc_\)\|\( \$[adt]\)' > $(1)
compile_objcopy = $(V)mkdir -p `dirname $(1)`; \
	     echo " (objcopy)   $(subst $(build_dir)/,,$(1))"; \
	     $(objcopy) -O binary $(2) $(1)
compile_ar = $(V)mkdir -p `dirname $(1)`; \
	     echo " (ar)        $(subst $(build_dir)/,,$(1))"; \
	     $(ar) -cq $(1) $(2); \
	     $(ar) -s $(1)
compile_xml = $(V)mkdir -p `dirname $(1)`; \
	      echo " (xsl)       $(subst $(build_dir)/,,$(1))"; \
	      $(xsl) --maxdepth 30000 --maxvars 30000 -o $(1) $(2) $(3)
compose_bin = $(V)mkdir -p `dirname $(1)`; \
	      echo " (compose)   $(subst $(build_dir)/,,$(1))"; \
	      cp -f $(2) $(1); \
	      for k in $(3) ; \
	        do j=`basename -s .elf $$k`; for i in .text .rodata ; \
		  do padress=`$(objdump) -hw $$k | grep $$i | sed -n 's/  */ /gp' | cut -d' ' -f 6`; \
	          $(objcopy) -O binary -j $$i $$k $$j$$i.bin; \
	          $(objcopy) --add-section .$$j$$i=$$j$$i.bin --set-section-flags .$$j$$i=alloc,contents,load,readonly --change-section-address .$$j$$i=0x$$padress $(1) $(1).tmp; \
		  rm $$j$$i.bin; \
		  cp $(1).tmp $(1); \
		  rm $(1).tmp; \
		done; \
	      done


# Setup list of objects.mk files
cpu-object-mks=$(shell if [ -d $(cpu_dir) ]; then find $(cpu_dir) -iname "objects.mk" | sort -r; fi)
cpu-common-object-mks=$(shell if [ -d $(cpu_common_dir) ]; then find $(cpu_common_dir) -iname "objects.mk" | sort -r; fi)
board-object-mks=$(shell if [ -d $(board_dir) ]; then find $(board_dir) -iname "objects.mk" | sort -r; fi)
board-device-object-mks=$(shell if [ -d $(board_device_dir) ]; then find $(board_device_dir) -iname "objects.mk" | sort -r; fi)
core-object-mks=$(shell if [ -d $(core_dir) ]; then find $(core_dir) -iname "objects.mk" | sort -r; fi)
kernel-libs-object-mks=$(shell if [ -d $(kernel_libs_dir) ]; then find $(kernel_libs_dir) -iname "objects.mk" | sort -r; fi)
common-libs-object-mks=$(shell if [ -d $(common_libs_dir) ]; then find $(common_libs_dir) -iname "objects.mk" | sort -r; fi)
apps-libs-object-mks=$(shell if [ -d $(apps_libs_dir) ]; then find $(apps_libs_dir) -iname "objects.mk" | sort -r; fi)
apps-object-mks=$(shell if [ -d $(apps_dir) ]; then find $(apps_dir)/$(CONFIG_ARCH) -iname "objects.mk" | sort -r; fi)

# Default rule "make" should always be first rule
.PHONY: all
all:

# Include all object.mk files
include $(cpu-object-mks)
include $(cpu-common-object-mks)
include $(board-object-mks)
include $(board-device-object-mks)
include $(core-object-mks)
include $(kernel-libs-object-mks)
include $(common-libs-object-mks)
include $(apps-libs-object-mks)
include $(apps-object-mks)

# Setup list of built-in objects
cpu-y=$(foreach obj,$(cpu-objs-y),$(build_dir)/kernel/arch/$(CONFIG_ARCH)/cpu/$(CONFIG_CPU)/$(obj))
cpu-common-y=$(foreach obj,$(cpu-common-objs-y),$(build_dir)/kernel/arch/$(CONFIG_ARCH)/cpu/common/$(obj))
board-y=$(foreach obj,$(board-objs-y),$(build_dir)/kernel/arch/$(CONFIG_ARCH)/board/$(CONFIG_BOARD)/$(obj))
board-device-y=$(foreach obj,$(board-device-objs-y),$(build_dir)/kernel/arch/$(CONFIG_ARCH)/board/device/$(obj))
core-y=$(foreach obj,$(core-objs-y),$(build_dir)/kernel/core/$(obj))
kernel-libs-y=$(foreach obj,$(kernel-libs-objs-y),$(build_dir)/kernel/libs/$(obj))
common-libs-y=$(foreach obj,$(common-libs-objs-y),$(build_dir)/libs/$(obj))
apps-libs-y=$(foreach obj,$(apps-libs-objs-y),$(build_dir)/apps/libs/$(obj))
apps-y=$(foreach obj,$(apps-objs-y),$(build_dir)/apps/$(obj))
apps-exec-all-y=$(foreach exec,$(apps-exec-y),$(build_dir)/$(exec))

targets-y+=$(apps-exec-all-y)

# Setup list of deps files for built-in objects
deps-y=$(cpu-y:.o=.dep)
deps-y+=$(cpu-common-y:.o=.dep)
deps-y+=$(board-y:.o=.dep)
deps-y+=$(board-device-y:.o=.dep)
deps-y+=$(core-y:.o=.dep)
deps-y+=$(kernel-libs-y:.o=.dep)
deps-y+=$(common-libs-y:.o=.dep)
deps-y+=$(apps-libs-y:.o=.dep)
deps-y+=$(apps-y:.o=.dep)

# Setup list of all built-in objects
kernel-all-y=$(build_dir)/kernel/arch/$(CONFIG_ARCH)/cpu/cpu.o
kernel-all-y+=$(build_dir)/kernel/arch/$(CONFIG_ARCH)/board/board.o
kernel-all-y+=$(build_dir)/kernel/core/core.o
ifneq ($(words $(kernel-libs-y)), 0)
kernel-all-y+=$(build_dir)/kernel/libs/libs.o
endif
ifneq ($(words $(apps-libs-y)), 0)
apps-all-y+=$(build_dir)/apps/libs/libs.a
endif
ifneq ($(words $(common-libs-y)), 0)
kernel-all-y+=$(build_dir)/libs/libs.a
apps-all-y+=$(build_dir)/libs/libs.a
endif
moth-all-y=$(build_dir)/apps.o
moth-all-y+=$(kernel-all-y)

# Preserve all intermediate files
.SECONDARY:

# Default rule "make"
.PHONY: all
all: $(CONFIG_FILE) $(tools-y) $(targets-y)

# Include additional rules for tools
include $(tools_dir)/rules.mk

$(build_dir)/os_task_ro.c: $(cpu_dir)/mmugen.xml $(xsl_common_dir)/task_config.xsl
	$(call compile_xml,$@,$(filter-out $<,$^),$<)

$(build_dir)/moth.bin: $(build_dir)/moth.elf
	$(call compile_objcopy,$@,$<)

$(build_dir)/moth.elf: $(build_dir)/moth.ld $(moth-all-y)
	$(call compile_ld,$@,$<,$(filter-out $<,$^))

$(build_dir)/apps.o: $(build_dir)/os_task_ro.o $(apps-exec-all-y)
	$(call compose_bin,$@,$<,$(filter-out $<,$^))

$(build_dir)/system.map: $(build_dir)/moth.elf
	$(call compile_nm,$@,$<)

$(build_dir)/linker.ld: $(cpu_dir)/linker.ld
	$(call compile_cpp,$@,$<)

$(build_dir)/kernel/arch/$(CONFIG_ARCH)/cpu/cpu.o: $(cpu-y) $(cpu-common-y)
	$(call merge_objs,$@,$^)

$(build_dir)/kernel/arch/$(CONFIG_ARCH)/board/board.o: $(board-y) $(board-device-y)
	$(call merge_objs,$@,$^)

$(build_dir)/kernel/core/core.o: $(core-y)
	$(call merge_objs,$@,$^)

$(build_dir)/kernel/libs/libs.o: $(kernel-libs-y)
	$(call merge_objs,$@,$^)

$(build_dir)/libs/libs.a: $(common-libs-y)
	$(call compile_ar,$@,$^)

$(build_dir)/apps/libs/libs.a: $(apps-libs-y)
	$(call compile_ar,$@,$^)

$(build_dir)/apps/apps.o: $(apps-y)
	$(call merge_objs,$@,$^)

$(build_dir)/%.dep: $(src_dir)/%.S
	$(call compile_as_dep,$@,$<)

$(build_dir)/%.dep: $(src_dir)/%.c
	$(call compile_cc_dep,$@,$<)

$(build_dir)/%.o: $(src_dir)/%.S
	$(call compile_as,$@,$<)

$(build_dir)/%.o: $(build_dir)/%.S
	$(call compile_as,$@,$<)

$(build_dir)/%.o: $(src_dir)/%.c
	$(call compile_cc,$@,$<)

$(build_dir)/%.o: $(build_dir)/%.c
	$(call compile_cc,$@,$<)

$(build_dir)/%.xo: $(build_dir)/%.o
	$(call copy_file,$@,$^)

$(build_dir)/apps/%.o: $(src_dir)/apps/$(CONFIG_ARCH)/%.c
	$(call compile_cc,$@,$<)

$(build_dir)/%.c: $(src_dir)/%.xml $(xsl_arch_dir)/mmugen.xsl
	$(call compile_xml,$@,$(filter-out $<,$^),$<)

$(build_dir)/%.ld: $(cpu_dir)/mmugen.xml $(xsl_arch_dir)/linker.xsl
	$(call compile_xml,$(build_dir)/moth.ld,$(filter-out $<,$^),$<)

$(build_dir)/%.elf: $(build_dir)/%.ld $(build_dir)/apps/%/main.o $(apps-all-y)
	$(call compile_ld,$@,$<,$(filter-out $<,$^))

# Include built-in and module objects dependency files
# Dependency files should only be included after default Makefile rule
# They should not be included for any "xxxconfig" or "xxxclean" rule
all-deps-1 = $(if $(findstring config,$(MAKECMDGOALS)),,$(deps-y))
all-deps-2 = $(if $(findstring clean,$(MAKECMDGOALS)),,$(all-deps-1))
-include $(all-deps-2)

# Rule for "make clean"
.PHONY: clean
clean:
ifeq ($(build_dir),$(CURDIR)/build)
	$(V)mkdir -p $(build_dir)
	$(if $(V), @echo " (clean)     $(build_dir)")
	$(V)find $(build_dir) -type d ! -name '$(shell basename $(CONFIG_DIR))' -a \
	! -name '$(shell basename $(build_dir))' -exec rm -rf {} +
	$(V)find $(build_dir) -maxdepth 1 -type f -exec rm -rf {} +
endif

# Rule for "make distclean"
.PHONY: distclean
distclean:
ifeq ($(build_dir),$(CURDIR)/build)
	$(if $(V), @echo " (rm)       $(build_dir)")
	$(V)rm -rf $(build_dir)
endif
	$(V)$(MAKE) -C $(src_dir)/tools/openconf clean

# Include config file rules
-include $(CONFIG_FILE).cmd

# Rule for "make menuconfig"
.PHONY: menuconfig
menuconfig:
	$(V)mkdir -p $(OPENCONF_TMPDIR)
	$(V)$(MAKE) -C tools/openconf menuconfig
	./tools/openconf/mconf $(OPENCONF_INPUT)

# Rule for "make oldconfig"
.PHONY: oldconfig
oldconfig:
	$(V)mkdir -p $(OPENCONF_TMPDIR)
	$(V)$(MAKE) -C tools/openconf oldconfig
	./tools/openconf/conf -s $(OPENCONF_INPUT)

# Rule for "make savedefconfig"
.PHONY: savedefconfig
savedefconfig:
	$(V)mkdir -p $(OPENCONF_TMPDIR)
	$(V)$(MAKE) -C tools/openconf savedefconfig
	./tools/openconf/conf -S $(OPENCONF_TMPDIR)/defconfig $(OPENCONF_INPUT)

# Rule for "make xxx-defconfig"
%-defconfig:
	$(V)mkdir -p $(OPENCONF_TMPDIR)
	$(V)$(MAKE) -C tools/openconf defconfig
	./tools/openconf/conf -D $(src_dir)/kernel/arch/$(ARCH)/configs/$@ $(OPENCONF_INPUT)
	./tools/openconf/conf -s $(OPENCONF_INPUT)

documentation:
	doxygen doc/moth.dox
