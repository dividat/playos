{ substituteAll
, version, disk, testingToplevel
, bindfs, qemu, OVMF, python39
}:
substituteAll {
  src = ./run-in-vm.py;
  inherit version disk testingToplevel;
  inherit bindfs qemu python39;
  ovmf = "${OVMF.fd}/FV/OVMF.fd";
}
