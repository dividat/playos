# ##############################################################################
# This Makefile will build an Alpine Linux root filesystem
#
# Required arguments are: $APKS: list of (space seperated) apks on build system
# to be installed on taget system $out: where to put the root filesystem
#
# Also required are the utilities proot and apk.static. They should either be
# in the $PATH or may be explicitly specified with the $PROOT and $APK_STATIC
# variables
# 
# ##############################################################################

# Tool location
PROOT ?= $(shell which proot)
APK_STATIC ?= $(shell which apk.static)


# Helper to run commands in target system
in_target = env -i PROOT_NO_SECCOMP=1 $(PROOT) \
						-S $(out) \
						-w /

# Option to mount all apks to be installed using proot
apk_proot_mount_args := $(foreach apk,$(APKS),$(addprefix "-b ",$(addsuffix :/mnt/apk/$(notdir $(apk)),$(apk))))

# Location of mounted apks in target system
apks_mounted := $(foreach apk,$(APKS),$(addprefix /mnt/apk/,$(notdir $(apk))))

.PHONY: bootstrap 
bootstrap:
	mkdir -p $(out)
	mkdir -p $(out)/sbin 
	mkdir -p $(out)/mnt

	$(in_target) \
		-b $(APK_STATIC):/sbin/apk.static \
		$(apk_proot_mount_args) \
		/sbin/apk.static \
			--no-network \
			--allow-untrusted \
			--initdb \
			add $(apks_mounted)

shell:
	$(in_target) /bin/sh

.PHONY: clean
clean:
	rm -rf $(out)
