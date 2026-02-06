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
  ];
  text = builtins.readFile ./playos-diagnostics.sh;
}
