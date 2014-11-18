################################################
#
# Makefile to Manage QuartusII/QSys Design
#
# Copyright Altera (c) 2014
# All Rights Reserved
#
################################################

SHELL := /bin/bash

.SUFFIXES: # Delete the default suffixes

include mks/default.mk

################################################
# Configuration

DL := downloads

# Source 
TCL_SOURCE = $(wildcard scripts/*.tcl)
QUARTUS_HDL_SOURCE = $(wildcard src/*.v) $(wildcard src/*.vhd) $(wildcard src/*.sv)
QUARTUS_MISC_SOURCE = $(wildcard src/*.stp) $(wildcard src/*.sdc)
PROJECT_ASSIGN_SCRIPTS = $(filter scripts/create_ghrd_quartus_%.tcl,$(TCL_SOURCE))

UBOOT_PATCHES = patches/soc_workshop_uboot_patch.patch
DTS_COMMON = board_info/hps_common_board_info.xml
DTS_BOARD_INFOS = $(wildcard board_info/board_info_*.xml)


# Board revisions
REVISION_LIST = $(patsubst create_ghrd_quartus_%,%,$(basename $(notdir $(PROJECT_ASSIGN_SCRIPTS))))

QUARTUS_DEFAULT_REVISION_FILE = \
        $(if \
        $(filter create_ghrd_quartus_$(PROJECT_NAME).tcl,$(notdir $(PROJECT_ASSIGN_SCRIPTS))), \
        create_ghrd_quartus_$(PROJECT_NAME).tcl, \
        $(firstword $(PROJECT_ASSIGN_SCRIPTS)))

QUARTUS_DEFAULT_REVISION = $(patsubst create_ghrd_quartus_%, \
        %, \
        $(basename $(notdir $(QUARTUS_DEFAULT_REVISION_FILE))))

SCRIPT_DIR = utils

# Project specific settings
PROJECT_NAME = soc_workshop_system
QSYS_BASE_NAME = soc_system
TOP_LEVEL_ENTITY = ghrd_top

QSYS_HPS_INST_NAME = hps_0
PRELOADER_DISABLE_WATCHDOG = 1
PRELOADER_FAT_SUPPORT = 1

#SW Config
ARCH := arm
CROSS_COMPILE := arm-linux-gnueabihf-
TOOLCHAIN_DIR := $(CURDIR)/toolchain
TOOLCHAIN_SOURCE := gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
TOOLCHAIN_SOURCE_PACKAGE := "http://releases.linaro.org/14.09/components/toolchain/binaries/$(TOOLCHAIN_SOURCE)"

# Kernel Config
#LNX_SOURCE_PACKAGE := "http://rocketboards.org/gitweb/?p=linux-socfpga.git;a=snapshot;h=refs/heads/socfpga-3.10-ltsi;sf=tgz"
LNX_SOURCE_PACKAGE := "http://rocketboards.org/gitweb/?p=linux-socfpga.git;a=snapshot;h=refs/heads/socfpga-3.17;sf=tgz"
LINUX_DEFCONFIG_TARGET = socfpga_custom_defconfig
LINUX_DEFCONFIG := $(wildcard linux.defconfig)
LINUX_MAKE_TARGET := zImage
KBUILD_BUILD_VERSION=$(shell /bin/date "+%Y-%m-%d---%H-%M-%S")
LNX_DEPS = linux.patches linux.dodefconfig toolchain.extract  buildroot.build

# Buildroot Config
BUILDROOT_DEFCONFIG_TARGET = br_custom_defconfig
BUILDROOT_DEFCONFIG := $(wildcard buildroot.defconfig)
BUSYBOX_CONFIG_FILE := $(wildcard $(CURDIR)/buildroot_busybox.config)
# NB: IF Buildroot is updated, the busybox-menuconfig stuff needs to be changed with an updated path.
BR_SOURCE_PACKAGE := "http://buildroot.uclibc.org/downloads/buildroot-2014.08.tar.gz"

# AR_FILTER_OUT := downloads

# initial save file list
AR_REGEX += ip readme.txt mks                                                                      
AR_REGEX += scripts                                                                        
AR_REGEX += $(SCRIPT_DIR) 
AR_REGEX += patches
AR_REGEX += board_info
AR_REGEX += hdl_src
AR_REGEX += sw_src
AR_REGEX += utils
AR_REGEX += overlay_template
AR_REGEX += downloads
AR_REGEX += *.defconfig
AR_REGEX += *.config

################################################
.PHONY: default
default: help
################################################

################################################
.PHONY: all
all: sd-fat

################################################
# DEPS
                                                                          
define create_deps
CREATE_PROJECT_STAMP_$1 := $(call get_stamp_target,create_project_$1)

QUARTUS_STAMP_$1 := $(call get_stamp_target,quartus_$1)

PRELOADER_GEN_STAMP_$1 := $(call get_stamp_target,preloader_gen-$1)
PRELOADER_FIXUP_STAMP_$1 := $(call get_stamp_target,preloader_fixup-$1)
PRELOADER_STAMP_$1 := $(call get_stamp_target,preloader-$1)

UBOOT_STAMP_$1 := $(call get_stamp_target,uboot-$1)

DTS_STAMP_$1 := $(call get_stamp_target,dts-$1)
DTB_STAMP_$1 := $(call get_stamp_target,dtb-$1)

QSYS_STAMP_$1 := $(call get_stamp_target,qsys_compile-$1)
QSYS_GEN_STAMP_$1 := $(call get_stamp_target,qsys_gen-$1)

QSYS_PIN_ASSIGNMENTS_STAMP_$1 := $$(call get_stamp_target,quartus_pin_assignments-$1)

QUARTUS_DEPS_$1 := $$(QUARTUS_PROJECT_STAMP_$1) $(QUARTUS_HDL_SOURCE) $(QUARTUS_MISC_SOURCE)
QUARTUS_DEPS_$1 += $$(CREATE_PROJECT_STAMP_$1)
QUARTUS_DEPS_$1 += $$(QSYS_PIN_ASSIGNMENTS_STAMP_$1) $$(QSYS_STAMP_$1)

PRELOADER_GEN_DEPS_$1 += $$(QUARTUS_STAMP_$1)
PRELOADER_FIXUP_DEPS_$1 += $$(PRELOADER_GEN_STAMP_$1)
PRELOADER_DEPS_$1 += $$(PRELOADER_FIXUP_STAMP_$1)

# QSYS_DEPS_$1 := $$(QSYS_GEN_STAMP_$1)
QSYS_DEPS_$1 := $1/$(QSYS_BASE_NAME).qsys
QSYS_GEN_DEPS_$1 := scripts/create_ghrd_qsys.tcl scripts/devkit_hps_configurations.tcl

#only support one custom board xml
DTS_BOARDINFO_$1 := $(firstword $(filter-out $1, $(DTS_BOARD_INFOS)))

DTS_DEPS_$1 := $$(DTS_BOARDINFO_$1) $(DTS_COMMON) $$(QSYS_STAMP_$1)
DTB_DEPS_$1 := $$(DTS_BOARDINFO_$1) $(DTS_COMMON) $$(QSYS_STAMP_$1)

QUARTUS_QPF_$1 := $1/$1.qpf
QUARTUS_QSF_$1 := $1/$1.qsf
QUARTUS_SOF_$1 := $1/output_files/$1.sof
QUARTUS_RBF_$1 := $1/output_files/$1.rbf

QSYS_FILE_$1 := $1/$(QSYS_BASE_NAME).qsys
QSYS_SOPCINFO_$1 := $1/$(QSYS_BASE_NAME).sopcinfo

DEVICE_TREE_SOURCE_$1 := $1/$(QSYS_BASE_NAME).dts
DEVICE_TREE_BLOB_$1 := $1/$(QSYS_BASE_NAME).dtb

#QSYS_SOPCINFO_$1 := $(patsubst $1/%.qsys,$1/%.sopcinfo,$$(QSYS_FILE_$1))
#DEVICE_TREE_SOURCE_$1 := $(patsubst $1/%.sopcinfo,$1/%.dts,$$(QSYS_SOPCINFO_$1))
#DEVICE_TREE_BLOB_$1 := $(patsubst $1/%.sopcinfo,$1/%.dtb,$$(QSYS_SOPCINFO_$1))

AR_FILES += $$(QUARTUS_RBF_$1) $$(QUARTUS_SOF_$1)	
AR_FILES += $$(QSYS_SOPCINFO_$1) $$(QSYS_FILE_$1)

AR_REGEX += $1/$(QSYS_BASE_NAME)/*.svd

AR_FILES += $$(DEVICE_TREE_SOURCE_$1)
AR_FILES += $$(DEVICE_TREE_BLOB_$1)

AR_FILES += $1/preloader/uboot-socfpga/u-boot.img
AR_FILES += $1/preloader/preloader-mkpimage.bin

SD_FAT_$1 += $$(QUARTUS_RBF_$1) $$(QUARTUS_SOF_$1)
SD_FAT_$1 += $$(DEVICE_TREE_SOURCE_$1) $$(DEVICE_TREE_BLOB_$1)
SD_FAT_$1 += $1/u-boot.img $1/preloader-mkpimage.bin
SD_FAT_$1 += $1/boot.script $1/u-boot.scr

.PHONY:$1.all
$1.all: $$(SD_FAT_$1)
HELP_TARGETS += $1.all
$1.all.HELP := Build Quartus / preloader / uboot / devicetree / boot scripts for $1 board

endef
$(foreach r,$(REVISION_LIST),$(eval $(call create_deps,$r)))


include mks/qsys.mk mks/quartus.mk mks/preloader_uboot.mk mks/devicetree.mk 
include mks/bootscript.mk mks/kernel.mk mks/buildroot.mk mks/overlay.mk

################################################

################################################
# Toolchain

.PHONY: toolchain.get
toolchain.get: $(DL)/$(TOOLCHAIN_SOURCE)
$(DL)/$(TOOLCHAIN_SOURCE):
	$(MKDIR) -p $(DL)
	wget -O $(DL)/$(TOOLCHAIN_SOURCE) $(TOOLCHAIN_SOURCE_PACKAGE)

.PHONY: toolchain.extract
toolchain.extract: $(call get_stamp_target,toolchain.extract)
$(call get_stamp_target,toolchain.extract): $(DL)/$(TOOLCHAIN_SOURCE)
	$(RM) $(TOOLCHAIN_DIR)
	$(MKDIR) $(TOOLCHAIN_DIR)
	$(TAR) -xvf $(DL)/$(TOOLCHAIN_SOURCE) --strip-components 1 -C $(TOOLCHAIN_DIR)
	$(stamp_target)

################################################

################################################
# All projects stuff
define create_project

.PHONY: create_project-$1
create_project-$1: $$(QSYS_GEN_STAMP_$1) $$(CREATE_PROJECT_STAMP_$1)

HELP_TARGETS_$1 += create_project-$1
create_project-$1.HELP := Create all files for $1 project

endef
$(foreach r,$(REVISION_LIST),$(eval $(call create_project,$r)))

.PHONY: create_all_projects
create_all_projects: $(foreach r,$(REVISION_LIST),create_project-$r)
HELP_TARGETS += create_all_projects
create_all_projects.HELP := Create all projects and qsys files

#.PHONY: compile_all_projects
#compile_all_projects: $(foreach r,$(REVISION_LIST),quartus_compile-$r)  
#HELP_TARGETS += compile_all_projects
#compile_all_projects.HELP := Compile all quartus projects

################################################

################################################

SD_FAT_TGZ := sd_fat.tar.gz

# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/output_files/$r.sof)  #sof
# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/output_files/$r.rbf)  #rbf
# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/boot.script)  #boot script source
# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/u-boot.scr)  #boot script
# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/preloader-mkpimage.bin) # preloader
# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/u-boot.img) # uboot
# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/$(QSYS_BASE_NAME).dts) #dts
# SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$r/$(QSYS_BASE_NAME).dtb) #dtb
SD_FAT_TGZ_DEPS += $(foreach r,$(REVISION_LIST),$(SD_FAT_$r))
SD_FAT_TGZ_DEPS += zImage

$(SD_FAT_TGZ): $(SD_FAT_TGZ_DEPS)
	@$(RM) $@
	@$(MKDIR) $(@D)
	$(TAR) -czf $@ $^

QUARTUS_OUT_TGZ := quartus_out.tar.gz 
QUARTUS_OUT_TGZ_DEPS += $(ALL_QUARTUS_RBF) $(ALL_QUARTUS_SOF)

$(QUARTUS_OUT_TGZ): $(QUARTUS_OUT_TGZ_DEPS)
	@$(RM) $@
	@$(MKDIR) $(@D)
	$(TAR) -czf $@ $^	
	
HELP_TARGETS += sd-fat
sd-fat.HELP := Generate tar file with contents for sdcard fat partition	
	
.PHONY: sd-fat
sd-fat: $(SD_FAT_TGZ)

AR_FILES += $(wildcard $(SD_FAT_TGZ))

SCRUB_CLEAN_FILES += $(SD_FAT_TGZ)

################################################


################################################
# Clean-up and Archive

AR_TIMESTAMP := $(if $(SOCEDS_VERSION),$(subst .,_,$(SOCEDS_VERSION))_)$(subst $(SPACE),,$(shell $(DATE) +%m%d%Y_%k%M%S))

AR_DIR := tgz
AR_FILE := $(AR_DIR)/soc_workshop_$(AR_TIMESTAMP).tar.gz

AR_FILES += $(filter-out $(AR_FILTER_OUT),$(wildcard $(AR_REGEX)))

CLEAN_FILES += $(filter-out $(AR_DIR) $(AR_FILES),$(wildcard *))

HELP_TARGETS += tgz
tgz.HELP := Create a tarball with the barebones source files that comprise this design

.PHONY: tarball tgz
tarball tgz: $(AR_FILE)

$(AR_FILE):
	@$(MKDIR) $(@D)
	@$(if $(wildcard $(@D)/*.tar.gz),$(MKDIR) $(@D)/.archive;$(MV) $(@D)/*.tar.gz $(@D)/.archive)
	@$(ECHO) "Generating $@..."
	@$(TAR) -czf $@ $(wildcard $(AR_FILES))

SCRUB_CLEAN_FILES += $(CLEAN_FILES)

HELP_TARGETS += scrub_clean
scrub_clean.HELP := Restore design to its barebones state

.PHONY: scrub scrub_clean
scrub scrub_clean:
	$(if $(strip $(wildcard $(SCRUB_CLEAN_FILES))),$(RM) $(wildcard $(SCRUB_CLEAN_FILES)),@$(ECHO) "You're already as clean as it gets!")

.PHONY: tgz_scrub_clean
tgz_scrub_clean:
	$(FIND) $(SOFTWARE_DIR) \( -name '*.o' -o -name '.depend*' -o -name '*.d' -o -name '*.dep' \) -delete || true
	$(MAKE) tgz AR_FILE=$(AR_FILE)
	$(MAKE) -s scrub_clean
	$(TAR) -xzf $(AR_FILE)

################################################


################################################
# Download everything

HELP_TARGETS += downloads
downloads.HELP := Download toolchain, kernel, and buildroot + required buildroot packages

.PHONY: downloads
downloads: toolchain.get buildroot.get linux.get buildroot.downloads

HELP_TARGETS += downloads_clean	
downloads_clean.HELP := Clean downloads directory

.PHONY: downloads_clean
downloads_clean: 
	$(RM) $(DL)/*

################################################


################################################
# Help system

.PHONY: help
help: help-init help-targets help-fini

.PHONY: help-revisions
help-revisions: help-revisions-init help-revisions-list help-revisions-fini help-revision-target

.PHONY: help-revs
help-revs: help-revisions-init help-revisions-list help-revisions-fini help-revision-target-short


HELP_TARGETS_X := $(patsubst %,help-%,$(sort $(HELP_TARGETS)))

HELP_TARGET_REVISION_X := $(foreach r,$(REVISION_LIST),$(patsubst %,help_rev-%,$(sort $(HELP_TARGETS_$r))))

HELP_TARGET_REVISION_SHORT_X := $(sort $(patsubst %-$(firstword $(REVISION_LIST)),help_rev-%-REVISIONNAME,$(filter-out $(firstword $(REVISION_LIST)),$(HELP_TARGETS_$(firstword $(REVISION_LIST))))))

$(foreach h,$(filter-out $(firstword $(REVISION_LIST)),$(HELP_TARGETS_$(firstword $(REVISION_LIST)))),$(eval $(patsubst %-$(firstword $(REVISION_LIST)),%-REVISIONNAME,$h).HELP := $(subst $(firstword $(REVISION_LIST)),REVISIONNAME,$($h.HELP)))) 

HELP_REVISION_LIST := $(patsubst %,rev_list-%,$(sort $(REVISION_LIST)))

#cheat, put help at the end
HELP_TARGETS_X += help-help-revisions
help-revisions.HELP := Displays Revision specific Target Help

HELP_TARGETS_X += help-help-revs
help-revs.HELP := Displays Short Revision specific Target Help


HELP_TARGETS_X += help-help
help.HELP := Displays this info (i.e. the available targets)


.PHONY: $(HELP_TARGETS_X)
help-targets: $(HELP_TARGETS_X)
$(HELP_TARGETS_X): help-%:
	@$(ECHO) "*********************"
	@$(ECHO) "* Target: $*"
	@$(ECHO) "*   $($*.HELP)"

.PHONY: help-init
help-init:
	@$(ECHO) "*****************************************"
	@$(ECHO) "*                                       *"
	@$(ECHO) "* Manage QuartusII/QSys design          *"
	@$(ECHO) "*                                       *"
	@$(ECHO) "*     Copyright (c) 2014                *"
	@$(ECHO) "*     All Rights Reserved               *"
	@$(ECHO) "*                                       *"
	@$(ECHO) "*****************************************"
	@$(ECHO) ""

.PHONY: help-revisions-init
help-revisions-init:
	@$(ECHO) ""
	@$(ECHO) "*****************************************"
	@$(ECHO) "*                                       *"
	@$(ECHO) "* Revision specific Targets             *"
	@$(ECHO) "*    target-REVISIONNAME                *"
	@$(ECHO) "*                                       *"
	@$(ECHO) "*    Available Revisions:               *"
	

.PHONY: $(HELP_REVISION_LIST)
help-revisions-list: $(HELP_REVISION_LIST)
$(HELP_REVISION_LIST): rev_list-%: 
	@$(ECHO) "*    -> $*"

.PHONY: help-revisions-fini
help-revisions-fini:
	@$(ECHO) "*                                       *"
	@$(ECHO) "*****************************************"
	@$(ECHO) ""

.PHONY: $(HELP_TARGET_REVISION_X)
.PHONY: $(HELP_TARGET_REVISION_SHORT_X)
help-revision-target: $(HELP_TARGET_REVISION_X)
help-revision-target-short: $(HELP_TARGET_REVISION_SHORT_X)
$(HELP_TARGET_REVISION_X) $(HELP_TARGET_REVISION_SHORT_X): help_rev-%:
	@$(ECHO) "*********************"
	@$(ECHO) "* Target: $*"
	@$(ECHO) "*   $($*.HELP)"
	
.PHONY: help-fini
help-fini:
	@$(ECHO) "*********************"

################################################