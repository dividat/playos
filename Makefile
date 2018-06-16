# Directories
WORK_DIR = work

# Target
TARGET_DISK = $(WORK_DIR)/disk.img
TARGET_ROOT = $(WORK_DIR)/target

# Alpine Linux
APK_VERSION = 2.9.1-r2
ALPINE_VERSION = 3.7
ALPINE_MIRROR = http://dl-cdn.alpinelinux.org/alpine
ALPINE_REPO = $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main

# Tools
APK_STATIC = $(shell which apk.static)
PROOT = $(shell which proot)

IN_TARGET = env -i PROOT_NO_SECCOMP=1 $(PROOT) \
						-S $(TARGET_ROOT) \
						-w /

# Bootstrap the base-system using apk.static
.PHONY: base-system
base-system: $(TARGET_DISK)
	mkdir -p $(TARGET_ROOT)

	# Mount disk image
	guestmount -a $(TARGET_DISK) -m /dev/sda2:/ -m /dev/sda1:/boot/ $(TARGET_ROOT)

	# Bootstrap with apk.static
	mkdir -p $(TARGET_ROOT)/sbin 
	$(IN_TARGET) \
		-b $(APK_STATIC):/sbin/apk.static \
		/sbin/apk.static -X $(ALPINE_REPO) \
		-U --allow-untrusted --initdb \
		-v \
		add alpine-base

	# Add repo and update 
	echo $(ALPINE_REPO) > $(TARGET_ROOT)/etc/apk/repositories
	$(IN_TARGET) /sbin/apk update

	# Install Linux kernel
	$(IN_TARGET) /sbin/apk add linux-hardened

	# bootloader
	$(IN_TARGET) /sbin/apk add gummiboot
	$(IN_TARGET) /bin/mkdir -p /boot/EFI/BOOT
	$(IN_TARGET) /bin/cp /usr/lib/gummiboot/gummibootx64.efi /boot/EFI/BOOT/BOOTX64.EFI
	$(IN_TARGET) \
		-b ./bootloader/ESP:/ESP \
		/bin/cp -r /ESP/loader /boot

	# Unmount disk image
	guestunmount $(TARGET_ROOT)

$(TARGET_DISK):
	mkdir -p $(WORK_DIR)
	guestfish -N $(TARGET_DISK)=bootroot:vfat:ext2:2000M:512M:efi \
		set-uuid /dev/sda2 f0b3cdfc-5dc1-4ce5-bfec-809a7a7b7426 :\
		mount /dev/sda2 / :\
		mkdir /boot :\
		mkdir /dev :\
		mkdir /proc :\
		mkdir /sys :\
		quit

shell:
	# Mount disk image
	guestmount -a $(TARGET_DISK) -m /dev/sda2:/ -m /dev/sda1:/boot/ $(TARGET_ROOT)
	$(IN_TARGET) /bin/sh
	# Unmount disk image
	guestunmount $(TARGET_ROOT)

qemu: $(WORK_DIR)/OVMF.fd
	qemu-system-x86_64 -pflash $(WORK_DIR)/OVMF.fd $(TARGET_DISK)

$(WORK_DIR)/OVMF.fd:
	cp $(OVMF) $(WORK_DIR)/OVMF.fd
	chmod +w $(WORK_DIR)/OVMF.fd

.PHONY: clean
clean:
	rm -rf $(WORK_DIR)
