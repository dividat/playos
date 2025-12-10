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

  # Note: all tools used here must be part of environment.systemPackages in the host system!
  compatScriptChecked = pkgs.writeShellApplication {
    name = "compat-script";
    text = ''
    if ! [[ "''${1:-}" == "slot-post-install" ]]; then
        echo "Expected to be run at phase 'slot-post-install'"
        exit 1
    fi

    BAD_EXT4_OPTION=metadata_csum_seed

    echo "== Running post-install system compatibility fixes"

    echo "RAUC_SLOT_DEVICE: $RAUC_SLOT_DEVICE"
    echo "RAUC_SLOT_MOUNT_POINT: $RAUC_SLOT_MOUNT_POINT"

    echo "== Checking for unsupported tune2fs options"

    # Perform the tuning
    if tune2fs -l "$RAUC_SLOT_DEVICE" | grep "Filesystem features" | grep "$BAD_EXT4_OPTION"; then

        echo "Detect $BAD_EXT4_OPTION, attempting to fix"

        echo "Unmounting $RAUC_SLOT_MOUNT_POINT"

        umount "$RAUC_SLOT_MOUNT_POINT"

        echo "Removing $BAD_EXT4_OPTION from $RAUC_SLOT_DEVICE"
        tune2fs -O ^"$BAD_EXT4_OPTION" "$RAUC_SLOT_DEVICE"

        echo "Re-mounting $RAUC_SLOT_DEVICE at $RAUC_SLOT_MOUNT_POINT"

        mount "$RAUC_SLOT_DEVICE" "$RAUC_SLOT_MOUNT_POINT"

        echo "Done!"

    else
        echo "No $BAD_EXT4_OPTION detected"
    fi
    '';
    };

    compatScript = pkgs.runCommand
        "compat-script-local.sh"
        { }
        # Replace shebang on first line with #!/bin/sh - this will run using the
        # host system's packages, not the packages from the system image!
        # Note: /bin/sh is an alias for bash on nixOS
        ''
        cp "${pkgs.lib.getExe compatScriptChecked}" $out
        sed -i '1 s|^.*$|#!/bin/sh|' $out
        '';
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

    cp ${compatScript} rauc-bundle/compat-fix.sh

    cat <<EOF > ./rauc-bundle/manifest.raucm
      [update]
      compatible=dividat-play-computer
      version=${version}

      [image.system]
      filename=system.tar.xz
      hooks=post-install

      [hooks]
      filename=compat-fix.sh
    EOF

    time rauc \
      --cert ${testingCert} \
      --key ${testingKey} \
      bundle \
      ./rauc-bundle/ \
      $out
  '';

}
