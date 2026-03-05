{ pkgs

, systemImage
, rescueSystem
, grubCfg
, version
, updateUrl
, kioskUrl
}:
with pkgs;
let
  systemClosureInfo = closureInfo { rootPaths = [ systemImage ]; };

  python = python3.withPackages(ps: with ps; [pyparted]);
in
stdenv.mkDerivation {
  name = "install-playos-${version}";

  src = substituteAll {
    src = ./install-playos.py;
    inherit grubCfg systemImage rescueSystem systemClosureInfo version updateUrl kioskUrl;
    inherit python;
  };

  buildInputs = [
    makeWrapper
    python
  ];

  buildCommand = ''
    mkdir -p $out/bin
    cp $src $out/bin/install-playos
    chmod +x $out/bin/install-playos

    patchShebangs $out/bin/install-playos
    # Add required tools to path
    wrapProgram $out/bin/install-playos \
      --prefix PATH ":" ${utillinux}/bin \
      --prefix PATH ":" ${e2fsprogs}/bin \
      --prefix PATH ":" ${dosfstools}/bin \
      --prefix PATH ":" ${grub2_efi}/bin \
      --prefix PATH ":" ${pv}/bin \
      --set-default MKE2FS_CONFIG ${../../base/compatibility/mke2fs.conf}

  '';
}
