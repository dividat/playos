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

  magicScriptSource = ''
trap "exit 101" EXIT

echo "== Running magic install-check script"

BUNDLE_VERSION=''${BUNDLE_VERSION:-${version}}

if ! [[ "''${1:-}" == "install-check" ]]; then
    echo "Expected to be run with 'install-check'"
    exit 1
fi

echo "== Step 1: Remove other RAUC bundles EXCEPT ourselves"
for f in /tmp/*.raucb; do
    if ! [[ "$f" == "/tmp/playos-$BUNDLE_VERSION.raucb" ]]; then
        rm -v "$f" || true
    fi
done

echo "== Step 2: Reset the failed status of select-display.service (if it exists)"

systemctl reset-failed select-display.service || true

echo "== Step 3: tune2fs the other partition"

BAD_EXT4_OPTION=metadata_csum_seed

# Figure out the disk label of the other partition

other_system=$(lsblk -o LABEL,MOUNTPOINTS -P | grep 'LABEL="system.' | grep 'MOUNTPOINTS=""' | cut -f2 -d'"') || echo ""

if ! [[ "$other_system" == "system.a" ]] && ! [[ "$other_system" == "system.b" ]]; then
    echo "Failed to determine other system (other_system='$other_system'), lsblk output:"
    lsblk -o LABEL,MOUNTPOINTS || true
    exit 101
fi

other_system_disk=/dev/disk/by-label/$other_system

# Perform the tuning

if tune2fs -l "$other_system_disk" | grep "Filesystem features" | grep "$BAD_EXT4_OPTION"; then

    echo "Attempting to remove $BAD_EXT4_OPTION from $other_system_disk"

    tune2fs -O ^"$BAD_EXT4_OPTION" "$other_system_disk"

    echo "Done!"

else
    echo "No $BAD_EXT4_OPTION detected"
fi

echo "== Step 4: Make sure the verification fails"
echo "Applied compatibility settings, waiting for next update" 1>&2
exit 101
  '';

  magicScriptForShellCheckOnly = pkgs.writeShellApplication {
    name = "do-not-use";
    text = magicScriptSource;
  };

  magicScript = pkgs.writeScript "magic-script" ''
#!/usr/bin/env bash
set -euo pipefail

${magicScriptSource}
    '';
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

    cp ${magicScript} rauc-bundle/magic-script.sh

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

  passthru.scriptCheck = magicScriptForShellCheckOnly;
  passthru.script = magicScript;
}
