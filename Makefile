WORK_DIR = ./work

qemu: $(WORK_DIR)/OVMF.fd $(WORK_DIR)/disk.img
	qemu-system-x86_64 -m 2048 -pflash $(WORK_DIR)/OVMF.fd $(WORK_DIR)/disk.img

.PHONY: $(WORK_DIR)/disk.img
$(WORK_DIR)/disk.img:
	mkdir -p $(WORK_DIR)
	cp $(disk) $@
	chmod +w $@

$(WORK_DIR)/OVMF.fd: $(OVMF)
	mkdir -p $(WORK_DIR)
	cp $(OVMF) $(WORK_DIR)/OVMF.fd
	chmod +w $(WORK_DIR)/OVMF.fd

.PHONY: clean
clean:
	rm -rf $(WORK_DIR)
