# Build NixOS system
{pkgs, lib, nixos, version}:
with lib;
let
  configuration = {config, ...}:
    {
      imports = [
        ../modules/system-partition.nix
        ../modules/volatile-root.nix
        ./configuration.nix

      ];

      options = {
        playos.version = mkOption {
          type = types.string;
          default = version;
        };
      };

      config = {

        # Use overlayed pkgs
        nixpkgs.pkgs = pkgs;

        # disable installation of bootloader
        boot.loader.grub.enable = false;

        playos = {
          inherit version;
        };
      };
    };

  testConfiguration = {...}:
    {
      imports = [
        configuration
        # FIXME: the importFromNixos should be in the pkgs anyways which is passed to the testing.nix module. But I get an infinite recursion somewhere if using from pkgs.
        ((import ../modules/testing.nix) {inherit (pkgs) importFromNixos;})
      ];
    };
in
{
  system = (nixos {
    inherit configuration;
    system = "x86_64-linux";
  }).config.system.build.toplevel;

  testing = (nixos {
    configuration = testConfiguration;
    system = "x86_64-linux";
  }).config.system.build.toplevel;

}
