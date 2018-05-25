WORK_DIR = work

BASE_SYSTEM_DIR = $(WORK_DIR)/base_system

APK_VERSION = 2.9.1-r2
ALPINE_VERSION = 3.7
ALPINE_MIRROR = http://dl-cdn.alpinelinux.org/alpine
ALPINE_REPO = $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main

APK_STATIC = $(WORK_DIR)/apk-static/sbin/apk.static
PROOT = $(shell which proot)

IN_TARGET = env -i PROOT_NO_SECCOMP=1 $(PROOT) -S $(BASE_SYSTEM_DIR) -w /

outside:
	mkdir -p $(BASE_SYSTEM_DIR)
	apk \
		-X $(ALPINE_REPO) \
		--root $(BASE_SYSTEM_DIR) \
		-U --allow-untrusted --initdb \
		add alpine-base
	$(IN_TARGET) /sbin/apk -X $(ALPINE_REPO) -U --allow-untrusted fix
	

base-system: $(APK_STATIC)
	mkdir -p $(BASE_SYSTEM_DIR)/sbin 
	$(IN_TARGET) \
		-b $(APK_STATIC):/sbin/apk.static \
		/sbin/apk.static -X $(ALPINE_REPO) \
		-U --allow-untrusted --initdb \
		-v \
		add alpine-base

shell:
	env -i \
		PROOT_NO_SECCOMP=1 \
		$(PROOT) -S $(BASE_SYSTEM_DIR) -w / \
		-v 1 \
		/bin/sh

$(APK_STATIC):
	mkdir -p $(WORK_DIR)/apk-static
	cd $(WORK_DIR)/apk-static && \
		wget $(ALPINE_REPO)/x86_64/apk-tools-static-$(APK_VERSION).apk && \
		tar xfz apk-tools-static-$(APK_VERSION).apk

.PHONY: clean
clean:
	rm -rf work



