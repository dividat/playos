{ pkgs }:
pkgs.writeShellApplication {
  name = "playos-collect-debug-info";
  runtimeInputs = with pkgs; [
    # script dependencies
    gnutar
    coreutils

    # diagonstic command dependencies
    iw
    wirelesstools
    connman
  ];
  text = builtins.readFile ./collect-debug-info.sh;
}
