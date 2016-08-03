# Copyright 2016 The Fuchsia Authors
#
# Use of this source code is governed by a MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT

# ensure that library deps are short-name style
$(foreach d,$(MODULE_LIBS),$(call modname-require-short,$(d)))
$(foreach d,$(MODULE_STATIC_LIBS),$(call modname-require-short,$(d)))

# build static library
$(MODULE_LIBNAME).a: $(MODULE_OBJS) $(MODULE_EXTRA_OBJS)
	@$(MKDIR)
	@echo linking $@
	@rm -f $@
	$(NOECHO)$(AR) cr $@ $^

# always build all libraries
EXTRA_BUILDDEPS += $(MODULE_LIBNAME).a
GENERATED += $(MODULE_LIBNAME).a

# modules that declare a soname desire to be shared libs as well
ifneq ($(MODULE_SO_NAME),)
MODULE_ALIBS := $(foreach lib,$(MODULE_STATIC_LIBS),$(call TOBUILDDIR,$(lib))/lib$(notdir $(lib)).a)
MODULE_SOLIBS := $(foreach lib,$(MODULE_LIBS),$(call TOBUILDDIR,$(lib))/lib$(notdir $(lib)).so)

$(MODULE_LIBNAME).so: _OBJS := $(MODULE_OBJS) $(MODULE_EXTRA_OBJS)
$(MODULE_LIBNAME).so: _LIBS := $(MODULE_ALIBS) $(MODULE_SOLIBS)
$(MODULE_LIBNAME).so: _SONAME := lib$(MODULE_SO_NAME).so
$(MODULE_LIBNAME).so: _LDFLAGS := $(MODULE_LDFLAGS)
$(MODULE_LIBNAME).so: $(MODULE_OBJS) $(MODULE_EXTRA_OBJS) $(MODULE_ALIBS) $(MODULE_SOLIBS)
	@$(MKDIR)
	@echo linking userlib $@
	$(NOECHO)$(LD) $(GLOBAL_LDFLAGS) $(USERLIB_SO_LDFLAGS) $(_LDFLAGS)\
		-shared -soname $(_SONAME) $(_OBJS) $(_LIBS) $(LIBGCC) -o $@

ALLUSER_LIBS += $(MODULE)
EXTRA_BUILDDEPS += $(MODULE_LIBNAME).so
GENERATED += $(MODULE_LIBNAME).so

ifeq ($(MODULE_SO_INSTALL_NAME),)
MODULE_SO_INSTALL_NAME := lib/lib$(MODULE_SO_NAME).so
endif
ifneq ($(MODULE_SO_INSTALL_NAME),-)
USER_MANIFEST_LINES += $(MODULE_SO_INSTALL_NAME)=$(MODULE_LIBNAME).so.strip
endif
endif


# if the SYSROOT build feature is enabled, we will package
# up exported libraries, their headers, etc
ifeq ($(ENABLE_BUILD_SYSROOT),true)

ifneq ($(MODULE_SO_NAME),)
TMP := $(BUILDDIR)/sysroot/lib/lib$(MODULE_SO_NAME).so
$(call copy-dst-src,$(TMP),$(MODULE_LIBNAME).so)
SYSROOT_DEPS += $(TMP)
GENERATED += $(TMP)
endif

ifneq ($(MODULE_EXPORT),)
ifneq ($(MODULE_EXPORT),system)
TMP := $(BUILDDIR)/sysroot/lib/lib$(MODULE_EXPORT).a
$(call copy-dst-src,$(TMP),$(MODULE_LIBNAME).a)
SYSROOT_DEPS += $(TMP)
GENERATED += $(TMP)
endif
endif

# only install headers for exported libraries
ifneq ($(MODULE_EXPORT)$(MODULE_SO_NAME),)
# for now, unify all headers in one pile
# TODO: ddk, etc should be packaged separately
MODULE_INSTALL_HEADERS := $(BUILDDIR)/sysroot/include

# locate headers from module source public include dir
MODULE_PUBLIC_HEADERS := $(shell test -d $(MODULE_SRCDIR)/include && find $(MODULE_SRCDIR)/include -name \*\.h -or -name \*\.inc)
MODULE_PUBLIC_HEADERS := $(patsubst $(MODULE_SRCDIR)/include/%,%,$(MODULE_PUBLIC_HEADERS))

# translate them to the final destination
MODULE_PUBLIC_HEADERS := $(patsubst %,$(MODULE_INSTALL_HEADERS)/%,$(MODULE_PUBLIC_HEADERS))

# generate rules to copy them
$(call copy-dst-src,$(MODULE_INSTALL_HEADERS)/%.h,$(MODULE_SRCDIR)/include/%.h)
$(call copy-dst-src,$(MODULE_INSTALL_HEADERS)/%.inc,$(MODULE_SRCDIR)/include/%.inc)

SYSROOT_DEPS += $(MODULE_PUBLIC_HEADERS)
GENERATED += $(MODULE_PUBLIC_HEADERS)
endif

endif # if ENABLE_BUILD_SYSROOT true