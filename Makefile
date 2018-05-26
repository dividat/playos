# Directories
WORK_DIR = work
BASE_SYSTEM_DIR = $(WORK_DIR)/base_system

# Alpine Linux
APK_VERSION = 2.9.1-r2
ALPINE_VERSION = 3.7
ALPINE_MIRROR = http://dl-cdn.alpinelinux.org/alpine
ALPINE_REPO = $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main

# Tools
APK_STATIC = $(shell which apk.static)
PROOT = $(shell which proot)

IN_TARGET = env -i PROOT_NO_SECCOMP=1 $(PROOT) -S $(BASE_SYSTEM_DIR) -w /

# Bootstrap the base-system using apk.static
.PHONY: base-system
base-system:
	mkdir -p $(BASE_SYSTEM_DIR)/sbin 
	$(IN_TARGET) \
		-b $(APK_STATIC):/sbin/apk.static \
		/sbin/apk.static -X $(ALPINE_REPO) \
		-U --allow-untrusted --initdb \
		-v \
		add alpine-base

shell:
	$(IN_TARGET) /bin/sh

.PHONY: clean
clean:
	rm -rf work
