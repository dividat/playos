{ vmTools, runCommand
, lib
, pkgs

, install-playos

, closureInfo
, rescueSystem
, systemImage

, # The data partition needs to be big enough to store at least a single RAUC
  # bundle, which currently is ~1.4GB, + other cached/persisted stuff
  dataPartSizeMiB ? 2000
}:
with lib;
let
  computeImageSizeMiB = image:
    let
        imageInfo = closureInfo { rootPaths = [ image ]; };
        closureSizeBytes = strings.toInt (builtins.readFile
            "${imageInfo}/total-nar-size");
        closureSizeMiB = closureSizeBytes / (1024.0*1024);
    in
        # add extra 20% because NAR size does not match real disk usage
        builtins.ceil(closureSizeMiB * 1.2);

  bootPartSizeMiB = computeImageSizeMiB rescueSystem;
  systemPartSizeMiB = computeImageSizeMiB systemImage;
  diskSizeMiB = 8 + bootPartSizeMiB + dataPartSizeMiB + systemPartSizeMiB*2 + 1;
in vmTools.runInLinuxVM (
  runCommand "build-playos-disk"
    {
      buildInputs = [install-playos];

      preVM = ''
        diskImage=nixos.raw
        echo "Boot partition size is: ${toString bootPartSizeMiB} MiB"
        echo "System partition size is: ${toString systemPartSizeMiB} MiB"
        echo "Computed disk size is: ${toString diskSizeMiB} MiB"
        truncate -s ${toString diskSizeMiB}MiB $diskImage
      '';

      postVM = ''
        mkdir -p $out
        mv $diskImage $out/playos-disk.img
        diskImage=$out/playos-disk.img
      '';
      memSize = 1024;
    }
    ''
      # machine-id of development image is hardcoded
      install-playos \
        --device /dev/vda \
        --machine-id "f414cca8312548d29689ebf287fb67e0" \
        --partition-size-boot ${toString bootPartSizeMiB} \
        --partition-size-system ${toString systemPartSizeMiB} \
        --partition-size-data ${toString dataPartSizeMiB} \
        --no-confirm
    ''
) + "/playos-disk.img"
