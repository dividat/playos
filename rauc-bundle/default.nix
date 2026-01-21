{ stdenv, perl, pixz, pathsFromGraph
, importFromNixos
, rauc
, version

, systemImage
, closureInfo
, pkgs
}:

let

  testingKey = ../pki/dummy/key.pem;
  testingCert = ../pki/dummy/cert.pem;

  systemClosureInfo = closureInfo { rootPaths = [ systemImage ]; };

  compatInstallCheckScript = (import ./compat-install-check-script.nix) { inherit pkgs; };
in
stdenv.mkDerivation {
  name = "bundle-${version}.raucb";

  buildInputs = [ rauc pixz ];

  buildCommand = ''
    # First create tarball with system content
    mkdir -p system
    cd system

    # The install-check script is expected to fail and abort the installation, but
    # in order to produce a valid bundle we crete a system image with a single
    # empty file.
    touch empty-system

    mkdir -p ../rauc-bundle
    time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c * | pixz > ../rauc-bundle/system.tar.xz

    cd ..

    # Add the install-check script to the bundle
    cp ${compatInstallCheckScript} rauc-bundle/install-check.sh

    cat <<EOF > ./rauc-bundle/manifest.raucm
      [update]
      compatible=dividat-play-computer
      version=${version}

      [image.system]
      filename=system.tar.xz

      [hooks]
      filename=install-check.sh
      hooks=install-check
    EOF

    time rauc \
      --cert ${testingCert} \
      --key ${testingKey} \
      bundle \
      ./rauc-bundle/ \
      $out
  '';

}
