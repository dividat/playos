{ stdenv
, substituteAll
, makeWrapper
, grub2
, e2fsprogs
, dosfstools
, utillinux
, gnutar
, xz
, python36

, systemTarball
, grubCfg
, version
}:
stdenv.mkDerivation {
  name = "install-playos-${version}";

  src = substituteAll {
    src = ./install-playos.py;
    inherit grubCfg systemTarball version;
  };

  buildInputs = [
    makeWrapper
    (python36.withPackages(ps: with ps; [pyparted]))
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
      --prefix PATH ":" ${grub2}/bin \
      --prefix PATH ":" ${gnutar}/bin \
      --prefix PATH ":" ${xz}/bin

  '';
  
}
