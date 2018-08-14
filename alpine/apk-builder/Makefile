# ##############################################################################
# This Makefile will build an Alpine Linux package (apk)
#
# Required arguments are: 
#  - $BUILD_SYSTEM: The rootfs of an Alpine system capable of building the package
#  - $APKBUILD_DIR: Folder containing APKBUILD file and other 
#  - $out: $where to place the build apk
#  - $tmp: temporary directory
#
# Also required are the utilities proot. They should either be in the $PATH or
# may be explicitly specified with the $PROOT variables
# 
# ##############################################################################

# Tool location
PROOT ?= $(shell which proot) 

# Helper to run commands in target system
in_target = env -i PROOT_NO_SECCOMP=1 $(PROOT) \
						-R $(BUILD_SYSTEM) \
						-w /

$out: $(TMPDIR)/build.sh $(TMPDIR)/key.rsa
	cp -r $(APKBUILD_DIR) $(TMPDIR)/apkbuild
	$(in_target) \
		-b $(TMPDIR):/tmp \
		/tmp/build.sh
	# This is super hacky!!! TODO: fix!
	cp $(TMPDIR)/package/tmp/x86_64/*.apk $(out)

$(TMPDIR)/build.sh:
	cat build.sh.in > $(TMPDIR)/build.sh
	chmod +x $(TMPDIR)/build.sh

$(TMPDIR)/key.rsa:
	cp key.rsa $(TMPDIR)/key.rsa

