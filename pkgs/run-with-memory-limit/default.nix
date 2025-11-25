{ pkgs, ... }:
pkgs.writeShellApplication {
    name = "run-with-memory-limit";
    runtimeInputs = with pkgs; [
        bash
        gawk
        systemd
        libuuid
    ];
    text = (builtins.readFile ./run-with-memory-limit.sh);
}
