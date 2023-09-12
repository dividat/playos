{ stdenv
, substituteAll
, makeWrapper
, grub2_efi
, e2fsprogs
, dosfstools
, utillinux
, python3
, pv
, closureInfo

, systemImage
, rescueSystem
, grubCfg
, version
, updateUrl
, kioskUrl
}:
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
      --prefix PATH ":" ${pv}/bin

  '';
}
