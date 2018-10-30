{ pkgs
, lib

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
        parted
        (grub2.override { efiSupport = true; })
        utillinux
        e2fsprogs
        dosfstools
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
      # Partition disk
      echo "Partitioning disk ... "
      parted --script /dev/vda -- \
        mklabel gpt \
        mkpart ESP fat32 8MiB 256MiB \
        set 1 boot on \
        mkpart primary ext4 1GiB ${toString dataPartitionSize}GiB \
        mkpart primary ext2 ${toString (1 + dataPartitionSize)}GiB ${toString (1 + dataPartitionSize + systemPartitionSize)}GiB \
        mkpart primary ext2 ${toString (1 + dataPartitionSize + systemPartitionSize)}GiB ${toString (1 + dataPartitionSize + systemPartitionSize + systemPartitionSize)}GiB

			echo "Creating ESP and installing boot loader ... "
			mkfs.vfat -n ESP /dev/vda1
      mkdir -p /mnt/boot
      mount /dev/vda1 /mnt/boot
      grub-install \
        --no-nvram \
        --no-bootsector \
        --removable \
        --boot-directory /mnt/boot \
        --target x86_64-efi \
        --efi-directory /mnt/boot
      cp $grubCfg /mnt/boot/grub/grub.cfg
      umount /dev/vda1

			echo "Creating data partition ... "
			mkfs.ext4 -L data /dev/vda2

			echo "Creating system.a partition ... "
			mkfs.ext4 -L system.a /dev/vda3
			mkdir -p /mnt/system.a
			mount /dev/vda3 /mnt/system.a
			tar xfJ ${systemTarball} -C /mnt/system.a
			umount /dev/vda3

			echo "Creating system.b partition ... "
			mkfs.ext4 -L system.b /dev/vda4
			mkdir -p /mnt/system.b
			mount /dev/vda4 /mnt/system.b
			tar xfJ ${systemTarball} -C /mnt/system.b
			umount /dev/vda4

    ''
)
