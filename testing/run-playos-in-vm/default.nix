{ substituteAll
, version, disk, testingToplevel
, bindfs, qemu, OVMF, python36
}:
substituteAll {
  src = ./run-playos-in-vm.py;
  inherit version disk testingToplevel;
  inherit bindfs qemu python36;
  ovmf = "${OVMF.fd}/FV/OVMF.fd";
}
