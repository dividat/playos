{ pkgs
, lib

, install-playos

, # The system to be installed on the disk
  systemTarball

, # Size of data partition in GiB
  dataPartitionSize ? 5

, # Size of system partition in GiB
  systemPartitionSize ? 5

, name ? "nixos-disk-image"

, # Output filename
  filename ? "nixos.img"
}:
with lib;
let 

  # disk size in GiB
  diskSize = (1 + dataPartitionSize + systemPartitionSize + systemPartitionSize + 1);

in pkgs.vmTools.runInLinuxVM (
  pkgs.runCommand name
    { 
      buildInputs = with pkgs; [ 
        install-playos
      ];
      grubCfg = ../bootloader/grub.cfg;
      preVM = ''
        diskImage=nixos.raw
        truncate -s ${toString diskSize}G $diskImage
      '';
      postVM = ''
        mkdir -p $out
        mv $diskImage $out/${filename}
        diskImage=$out/${filename}
      '';
      memSize = 1024;
    }
    ''
      # machine-id of development image is hardcoded
      install-playos \
        --device /dev/vda \
        --machine-id "f414cca8312548d29689ebf287fb67e0" \
        --no-confirm
    ''
)
