{ substituteAll
, version, disk, toplevel
, bindfs, qemu, OVMF
}:
substituteAll {
  src = ./run-playos-in-vm.py;
  inherit version disk toplevel;
  inherit bindfs qemu;
  ovmf = "${OVMF.fd}/FV/OVMF.fd";
}
