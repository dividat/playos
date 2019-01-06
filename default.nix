{ buildInstaller ? true
, buildBundle ? true
, buildDisk ? true }:
let
  pinnedNixpkgs = import ./nixpkgs;
  pkgs = pinnedNixpkgs.nixpkgs {
    overlays = [
      (import ./pkgs)
      (self: super: {
        inherit (pinnedNixpkgs) importFromNixos;
      })
    ];
};
in
let

  # lib.makeScope returns consistent set of packages that depend on each other (and is my new favorite nixpkgs trick)
  components = pkgs.lib.makeScope pkgs.newScope (self: with self; {

    # Set version
    version = "2018.12.0-dev";

    # NixOS system toplevels (for production and testing systems)
    # TODO: I don't like the names toplevels and the fact that the testing and production systems are bundled up together.
    toplevels = callPackage ./system {};

    # Installation script
    install-playos = callPackage ./installer/install-playos {
      toplevel = toplevels.system;
      grubCfg = ./bootloader/grub.cfg;
    };

    # Installer ISO image
    installer = callPackage ./installer {};

    # Disk image containing pre-installed system
    disk = if buildDisk then callPackage ./testing/disk {} else null;

    # RAUC bundle
    raucBundle = callPackage ./rauc-bundle {
      toplevel = toplevels.system;
    };

    # Script for spinning up VMs
    run-playos-in-vm = callPackage ./testing/run-playos-in-vm {
      toplevel = toplevels.testing;
    };

  });
in

with pkgs;
stdenv.mkDerivation {
  name = "playos-${components.version}";

  buildInputs = [
    rauc
    (python36.withPackages(ps: with ps; [pyparted]))
    components.install-playos
  ];

  buildCommand = ''
    mkdir -p $out

    # Helper to run in vm
    mkdir -p $out/bin
    cp ${components.run-playos-in-vm} $out/bin/run-playos-in-vm
    chmod +x $out/bin/run-playos-in-vm
    patchShebangs $out/bin/run-playos-in-vm
  ''
  # Installer ISO image
  + lib.optionalString buildInstaller ''
    ln -s ${components.installer}/iso/playos-installer-${components.version}.iso $out/playos-installer-${components.version}.iso
  ''
  # RAUC bundle
  + lib.optionalString buildBundle ''
    ln -s ${components.raucBundle} $out/playos-${components.version}.raucb
  '';

}
