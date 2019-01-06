# Build NixOS system
{pkgs, lib, version}:
with lib;
let nixos = pkgs.importFromNixos ""; in
{
  system = (nixos {
    configuration = {...}: {
      imports = [
        # general PlayOS modules
        ((import ./modules/playos.nix) {inherit version pkgs;})

        # system configuration
        ./configuration.nix
      ];
    };
    system = "x86_64-linux";
  }).config.system.build.toplevel;

  testing = (nixos {
    configuration = {...}: {
    imports = [
      # general PlayOS modules
      ((import ./modules/playos.nix) {inherit version pkgs;})

      # system configuration
      ./configuration.nix

      # Testing machinery
      # FIXME: the importFromNixos should be in the pkgs anyways which is passed to the testing.nix module. But I get an infinite recursion somewhere if using from pkgs.
      ((import ./modules/testing.nix) {inherit (pkgs) importFromNixos;})
    ];
    };
    system = "x86_64-linux";
  }).config.system.build.toplevel;

}
