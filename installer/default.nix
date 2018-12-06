# Build NixOS system
{config, lib, pkgs,
 nixos, importFromNixos,
 version, grubCfg, systemTarball
 }:
let
  install-playos = (import ./install-playos) {
    inherit (pkgs) stdenv substituteAll makeWrapper python36 utillinux e2fsprogs dosfstools gnutar xz;
    inherit grubCfg systemTarball version;
    grub2 = (pkgs.grub2.override { efiSupport = true; });
  };

in
  {
    inherit install-playos;

  }

