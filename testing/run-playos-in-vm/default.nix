{ substituteAll
, version, disk, testingToplevel
, bindfs, qemu, OVMF
}:
substituteAll {
  src = ./run-playos-in-vm.py;
  inherit version disk testingToplevel;
  inherit bindfs qemu;
  ovmf = "${OVMF.fd}/FV/OVMF.fd";
}
