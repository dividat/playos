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

  magicScript = pkgs.writeShellApplication {
    name = "magic-script";
    text = ''
        set -x

        if ! [[ "$1" == "install-check" ]]; then
            print "Expected to be run with 'install-check'"
            exit 1
        fi

        # Step 1: Remove other RAUC bundles EXCEPT ourselves
        for f in /tmp/*.raucb; do
            if ! [[ "$f" == "/tmp/playos-bundle-${version}.raucb" ]]; then
                rm "$f" || true
            fi
        done

        # Step 2: tune2fs the other partition

        BAD_EXT4_OPTION=metadata_csum_seed

        # Figure out the disk label of the other partition

        booted_system=$(rauc status | grep "Booted from:" | cut -f3 -d' ')

        if [[ "$booted_system" == "system.a" ]]; then
            other_system=system.b
        else
            other_system=system.a
        fi

        other_system_disk=/dev/disk/by-label/$other_system

        # Perform the tuning

        if tune2fs -l "$other_system_disk" | grep "Filesystem features" | grep $BAD_EXT4_OPTION; then

            print "Attempting to remove $BAD_EXT4_OPTION from $other_system_disk"

            tune2fs -O ^$BAD_EXT4_OPTION -l "$other_system_disk"

            print "Done!"

        else
            print "No $BAD_EXT4_OPTION detected"
        fi


        # Step 3: Reset the failed status of select-display.service (if it exists)

        systemctl reset-failed select-display.service || true

        # Step 4: Make sure the verification fails
        print "Installation successfully failed :-)"

        exit 101
    '';
  };
in
stdenv.mkDerivation {
  name = "bundle-${version}.raucb";

  buildInputs = [ rauc pixz ];

  buildCommand = ''
    # First create tarball with system content
    mkdir -p system
    cd system

    touch empty-system

    mkdir -p ../rauc-bundle
    time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c * | pixz > ../rauc-bundle/system.tar.xz

    cd ..

    cp ${pkgs.lib.getExe magicScript} magic-script.sh

    cat <<EOF > ./rauc-bundle/manifest.raucm
      [update]
      compatible=dividat-play-computer
      version=${version}

      [image.system]
      filename=system.tar.xz

      [hooks]
      filename=magic-script.sh
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
