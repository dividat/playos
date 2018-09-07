WORK_DIR = ./work

qemu: $(WORK_DIR)/OVMF.fd $(WORK_DIR)/nixos.img
	qemu-system-x86_64 -m 2048 -pflash $(WORK_DIR)/OVMF.fd $(WORK_DIR)/nixos.img

$(WORK_DIR)/nixos.img: $(DIVIDAT_LINUX_DISK_IMAGE)
	mkdir -p $(WORK_DIR)
	cp $< $@
	chmod +w $@

$(WORK_DIR)/OVMF.fd: $(OVMF)
	mkdir -p $(WORK_DIR)
	cp $(OVMF) $(WORK_DIR)/OVMF.fd
	chmod +w $(WORK_DIR)/OVMF.fd

.PHONY: clean
clean:
	rm -rf $(WORK_DIR)
