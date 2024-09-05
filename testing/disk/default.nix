{ vmTools, runCommand
, lib

, install-playos

, # Size of data partition in GiB
  dataPartitionSize ? 5

, # Size of system partition in GiB
  systemPartitionSize ? 10
}:
with lib;
let
  # disk size in GiB
  diskSize = (1 + dataPartitionSize + systemPartitionSize + systemPartitionSize + 1);
in vmTools.runInLinuxVM (
  runCommand "build-playos-disk"
    {
      buildInputs = [install-playos];

      preVM = ''
        diskImage=nixos.raw
        truncate -s ${toString diskSize}G $diskImage
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
