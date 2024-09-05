{ vmTools, runCommand
, lib

, install-playos

, closureInfo
, systemImage

, # Size of data partition in GB
  dataPartitionSize ? 1
, bootPartitionSize ? 1
}:
with lib;
let
  systemClosureInfo = closureInfo { rootPaths = [ systemImage ]; };
  systemSizeBytes = strings.toInt (builtins.readFile "${systemClosureInfo}/total-nar-size");
  systemSizeGB = systemSizeBytes / (1000.0*1000*1000);
  # add extra 20% because nar size is not accurate
  systemPartitionSize = builtins.ceil (systemSizeGB * 1.2);
  diskSize = bootPartitionSize + dataPartitionSize + systemPartitionSize*2;
in vmTools.runInLinuxVM (
  runCommand "build-playos-disk"
    {
      buildInputs = [install-playos];

      preVM = ''
        diskImage=nixos.raw
        echo "System image (closure) size is: ${toString systemSizeGB} GB"
        echo "System partition size is: ${toString systemPartitionSize} GB"
        echo "Computed disk size is: ${toString diskSize} GB"
        truncate -s ${toString diskSize}GB $diskImage
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
        --partition-size-system ${toString systemPartitionSize} \
        --partition-size-data ${toString dataPartitionSize} \
        --no-confirm
    ''
) + "/playos-disk.img"
