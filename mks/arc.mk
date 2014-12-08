
ARC_BUILD_INTERMEDIATE_TARGETS := $(foreach r,$(REVISION_LIST),$r.all)

.PHONY: arc_build_all
arc_build_all:
	make arc_init_build
	make -j8 $(ARC_BUILD_INTERMEDIATE_TARGETS)
	make -j8 all


.phony: arc_build_init
arc_build_init:
	make -j8 http_proxy=$(HTTP_PROXY) https_proxy=$(HTTPS_PROXY) downloads
	make -j8 create_all_projects
	
define arc_build_project

.PHONY: arc_build-$1
arc_build-$1:
	arc submit --watch -- arc vnc make $1.all

endef

$(foreach r,$(REVISION_LIST),$(eval $(call arc_build_project,$r)))