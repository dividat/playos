{ replaceVars
, version, disk, testingToplevel
, bindfs, qemu, OVMF, python3
}:
replaceVars ./run-in-vm.py {
  inherit version disk testingToplevel;
  inherit bindfs qemu python3;
  ovmf = "${OVMF.fd}/FV/OVMF.fd";
}
