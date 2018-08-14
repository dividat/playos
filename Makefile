# Directories
WORK_DIR = work

TARGET_DISK = $(WORK_DIR)/disk.img
ROOT_TAR = $(WORK_DIR)/root.tar

$(TARGET_DISK): $(ROOT_TAR)
	guestfish -N $(TARGET_DISK)=bootroot:vfat:ext2:2000M:512M:efi \
		set-uuid /dev/sda2 f0b3cdfc-5dc1-4ce5-bfec-809a7a7b7426 :\
		mount /dev/sda2 / :\
		mkdir /boot :\
		mkdir /dev :\
		mkdir /proc :\
		mkdir /sys :\
		mount /dev/sda1 /boot :\
		tar-in $(ROOT_TAR) / xattrs:true :\
		mkdir-p /boot/EFI/BOOT :\
		cp /usr/lib/gummiboot/gummibootx64.efi /boot/EFI/BOOT/BOOTX64.EFI :\
		glob copy-in ./bootloader/ESP/* /boot :\
		quit

$(ROOT_TAR):
	mkdir -p $(WORK_DIR)
	tar cf $(ROOT_TAR) -C $(ROOT_FS) .

# Helper to run commands in mounted root
mounted_root = $(WORK_DIR)/mnt
PROOT=$(shell which proot)
in_target = env -i PROOT_NO_SECCOMP=1 $(PROOT) \
						-S $(mounted_root) \
            -w /

shell: $(TARGET_DISK)
	mkdir -p $(mounted_root)
	# Mount disk image
	guestmount -a $(TARGET_DISK) -m /dev/sda2:/ -m /dev/sda1:/boot/ $(mounted_root)
	$(in_target) /bin/sh
	# Unmount disk image
	guestunmount $(mounted_root)

qemu: $(WORK_DIR)/OVMF.fd
	qemu-system-x86_64 -pflash $(WORK_DIR)/OVMF.fd $(TARGET_DISK)

$(WORK_DIR)/OVMF.fd:
	cp $(OVMF) $(WORK_DIR)/OVMF.fd
	chmod +w $(WORK_DIR)/OVMF.fd

# Helper to get latest upstream apks
.PHONY: update-upstream-apks
update-upstream-apks:
	apk2nix -o alpine/systems/alpine-base.nix alpine-base
	apk2nix -o alpine/systems/alpine-sdk.nix alpine-base alpine-sdk
	apk2nix -o system/apks.nix alpine-base linux-hardened gummiboot

.PHONY: clean
clean:
	rm -rf $(WORK_DIR)
