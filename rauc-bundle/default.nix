{ stdenv, perl, pixz, pathsFromGraph
, importFromNixos
, rauc
, version, cert, key
, systemToplevel
}:

let
  systemTarball = (importFromNixos "lib/make-system-tarball.nix") {
    inherit stdenv perl pixz pathsFromGraph;

    fileName = "system";

    contents = [
      {
        source = toplevel + "/initrd";
        target = "/initrd";
      }
      {
        source = toplevel + "/kernel";
        target = "/kernel";
      }
      {
        source = toplevel + "/init" ;
        target = "/init";
      }
    ];

    storeContents = [{
        object = toplevel;
        symlink = "/run/current-system";
      }];
  } + "/tarball/system.tar.xz";
in
stdenv.mkDerivation {
  name = "bundle-${version}.raucb";

  buildInputs = [ rauc ];

  buildCommand = ''
    mkdir -p $TEMP/rauc-bundle

    cp --dereference ${systemTarball} $TEMP/rauc-bundle/system.tar.xz

    cat <<EOF > $TEMP/rauc-bundle/manifest.raucm
      [update]
      compatible=Dividat Play Computer
      version=${version}

      [image.system]
      filename=system.tar.xz
    EOF

    rauc \
      --cert ${cert} \
      --key ${key} \
      bundle \
      $TEMP/rauc-bundle/ \
      $out
  '';

}
