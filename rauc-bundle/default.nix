{ stdenv, perl, pixz, pathsFromGraph
, importFromNixos
, rauc
, version

, systemImage
, closureInfo
}:

let

  testingKey = ../pki/dummy/key.pem;
  testingCert = ../pki/dummy/cert.pem;

  systemClosureInfo = closureInfo { rootPaths = [ systemImage ]; };

  # TODO: Create tar ball used for RAUC bundle in one derivation. This will reduce disk space usage as the tarball alone is not (unnecessarily) stored in the nix store.
  systemTarball = (importFromNixos "lib/make-system-tarball.nix") {
    inherit stdenv perl pixz pathsFromGraph;

    fileName = "system";

    contents = [
      {
        source = systemImage + "/initrd";
        target = "/initrd";
      }
      {
        source = systemImage + "/kernel";
        target = "/kernel";
      }
      {
        source = systemImage + "/init" ;
        target = "/init";
      }
    ];

    storeContents = [{
        object = systemImage;
        symlink = "/run/current-system";
      }];
  } + "/tarball/system.tar.xz";
in
stdenv.mkDerivation {
  name = "bundle-${version}.raucb";

  buildInputs = [ rauc pixz ];

  buildCommand = ''
    # First create tarball with system content
    mkdir -p system
    cd system

    # Copy store content
    mkdir -p nix/store
    for i in $(< ${systemClosureInfo}/store-paths); do
        cp -a "$i" ".$i"
    done

    # copy initrd, kernel and init
    cp -a "${systemImage}/initrd" initrd
    cp -a "${systemImage}/kernel" kernel
    cp -a "${systemImage}/init" init

    mkdir -p ../rauc-bundle
    time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c * | pixz > ../rauc-bundle/system.tar.xz

    cd ..

    cat <<EOF > ./rauc-bundle/manifest.raucm
      [update]
      compatible=dividat-play-computer
      version=${version}

      [image.system]
      filename=system.tar.xz
    EOF

    time rauc \
      --cert ${testingCert} \
      --key ${testingKey} \
      bundle \
      ./rauc-bundle/ \
      $out
  '';

}
