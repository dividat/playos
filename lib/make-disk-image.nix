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
        libguestfs
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
      parted --script /dev/vda -- \
        mklabel gpt \
        mkpart ESP fat32 8MiB 256MiB \
        set 1 boot on \
        mkpart primary ext4 1GiB ${toString dataPartitionSize}GiB \
        mkpart primary ext2 ${toString (1 + dataPartitionSize)}GiB ${toString (1 + dataPartitionSize + systemPartitionSize)}GiB \
        mkpart primary ext2 ${toString (1 + dataPartitionSize + systemPartitionSize)}GiB ${toString (1 + dataPartitionSize + systemPartitionSize + systemPartitionSize)}GiB

      echo -n "Preparing disk with guestfish ... "
      export LIBGUESTFS_PATH=${pkgs.libguestfs}/lib/guestfs
      guestfish <<EOF
        # load drive
        add-drive /dev/vda
        run

        # Set the disk identifier to a fixed GUID (to avoid randomness in builds)
        part-set-disk-guid /dev/sda 304C816E-C72A-48C6-B5CB-E02081AA23A3

        # EFI system partition (ESP)
        part-set-bootable /dev/sda 1 true
        part-set-gpt-type /dev/sda 1 C12A7328-F81F-11D2-BA4B-00A0C93EC93B
        part-set-gpt-guid /dev/sda 1 f748c4b5-84df-46ba-b9af-f4e07915824f
        mkfs vfat /dev/sda1 label:ESP
        mount /dev/sda1 /
        # tar-in $espTarball / compress:xz xattrs:true
        unmount /

        # Data partition
        part-set-gpt-type /dev/sda 2 A2A0D0EB-E5B9-3344-87C0-68B6B72699C7
        part-set-gpt-guid /dev/sda 2 937ec359-838f-4636-8439-d1cd1f2d4beb 
        mkfs ext4 /dev/sda2 label:data

        # System A partition
        part-set-gpt-type /dev/sda 3 4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 
        part-set-gpt-guid /dev/sda 3 f08afd4e-6076-4700-b23f-893e40c80d3c
        mkfs ext2 /dev/sda3 label:system-a
        mount /dev/sda3 /
        tar-in ${systemTarball} / compress:xz xattrs:true
        unmount /

        # System B partition
        part-set-gpt-type /dev/sda 4 4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 
        part-set-gpt-guid /dev/sda 4 b1672b7f-7dd9-46f4-9fb5-4d119b847809
        mkfs ext2 /dev/sda4 label:system-b
        mount /dev/sda4 /
        tar-in ${systemTarball} / compress:xz xattrs:true
        unmount /

        quit
      EOF
      echo "done."

      mkdir -p /mnt/boot
      mount /dev/vda1 /mnt/boot
      grub-install -v --no-nvram --no-bootsector --removable \
        --boot-directory /mnt/boot \
        --target x86_64-efi \
        --efi-directory /mnt/boot

      cp $grubCfg /mnt/boot/grub/grub.cfg
    ''
)
