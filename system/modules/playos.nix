# This is the toplevel module for all PlayOS related functionalities.

# Things that are injected into the system
{pkgs, version, updateCert, kioskUrl, playos-controller}:


{config, lib, ...}:
with lib;
{
  imports = [
    ./system-partition.nix
    ./volatile-root.nix
  ];

  options = {
    playos.version = mkOption {
      type = types.string;
      default = version;
    };

    playos.kioskUrl = mkOption {
      type = types.string;
    };

    playos.updateCert = mkOption {
      type = types.package;
    };

  };

  config = {

    # Use overlayed pkgs.
    nixpkgs.pkgs = pkgs;

    # disable installation of bootloader
    boot.loader.grub.enable = false;

    playos = {
      inherit version updateCert kioskUrl;
    };

    # Start controller
    systemd.services.playos-controller = {
      description = "PlayOS Controller";
      serviceConfig = {
        ExecStart = "${playos-controller}/bin/playos-controller";
        User = "root";
        RestartSec = "10s";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
      requires = [ "rauc" "connman" ];
      after = [ "rauc" "connman" ];
    };

  };
}
