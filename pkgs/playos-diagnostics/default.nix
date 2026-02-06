{ pkgs }:
pkgs.writeShellApplication {
  name = "playos-diagnostics";
  runtimeInputs = with pkgs; [
    # script dependencies
    gnutar
    coreutils

    # diagonstic command dependencies
    iw
    wirelesstools
    connman
    dmidecode
    lshw
    rauc
    grub2_efi
    curl
  ];
  text = builtins.readFile ./playos-diagnostics.sh;
}
