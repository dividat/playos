{ stdenv
, libguestfs
, parted
, name ? "disk-image.img"
# Size of data partition in GiB
, dataPartitionSize ? 5
# Size of system partition in GiB
, systemPartitionSize ? 5
, systemTarball
, espTarball
}:
let
  # disk size in GiB
  diskSize = (1 + dataPartitionSize + systemPartitionSize + systemPartitionSize + 1);
in
stdenv.mkDerivation {
  inherit name;

  buildInputs = [
    libguestfs
    parted
  ];

  phases = [ "buildPhase" ];

  buildPhase = ''

    # Create disk image
    truncate -s ${toString diskSize}G $out

    echo -n "Partitioning disk ... "
    parted --script $out -- \
      mklabel gpt \
      mkpart ESP fat32 8MiB 256MiB \
      set 1 boot on \
      mkpart primary fat32 256MiB 512MiB \
      mkpart primary ext4 1GiB ${toString dataPartitionSize}GiB \
      mkpart primary ext2 ${toString (1 + dataPartitionSize)}GiB ${toString (1 + dataPartitionSize + systemPartitionSize)}GiB \
      mkpart primary ext2 ${toString (1 + dataPartitionSize + systemPartitionSize)}GiB ${toString (1 + dataPartitionSize + systemPartitionSize + systemPartitionSize)}GiB
    echo "done."

    
    echo -n "Preparing disk with guestfish ... "
    export LIBGUESTFS_PATH=${libguestfs}/lib/guestfs
    guestfish <<EOF
      # load drive
      add-drive $out
      run

      # Set the disk identifier to a fixed GUID (to avoid randomness in builds)
      part-set-disk-guid /dev/sda 304C816E-C72A-48C6-B5CB-E02081AA23A3

      # EFI system partition (ESP)
      part-set-bootable /dev/sda 1 true
      part-set-gpt-type /dev/sda 1 C12A7328-F81F-11D2-BA4B-00A0C93EC93B
      part-set-gpt-guid /dev/sda 1 f748c4b5-84df-46ba-b9af-f4e07915824f
      mkfs vfat /dev/sda1 label:ESP
      mount /dev/sda1 /
      tar-in ${espTarball} / compress:xz xattrs:true
      unmount /

      # Barebox data partition
      part-set-gpt-type /dev/sda 2 ebc02da5-e753-4d1c-ab79-291d65a0a2ad
      part-set-gpt-guid /dev/sda 2 b4195b76-5eea-4f09-81ff-1e0e3237899c

      # Data partition
      part-set-gpt-type /dev/sda 3 A2A0D0EB-E5B9-3344-87C0-68B6B72699C7
      part-set-gpt-guid /dev/sda 3 937ec359-838f-4636-8439-d1cd1f2d4beb 
      mkfs ext4 /dev/sda3 label:data

      # System A partition
      part-set-gpt-type /dev/sda 4 4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 
      part-set-gpt-guid /dev/sda 4 f08afd4e-6076-4700-b23f-893e40c80d3c
      mkfs ext2 /dev/sda4 label:system-a
      mount /dev/sda4 /
      tar-in ${systemTarball} / compress:xz xattrs:true
      unmount /

      # System B partition
      part-set-gpt-type /dev/sda 5 4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 
      part-set-gpt-guid /dev/sda 5 b1672b7f-7dd9-46f4-9fb5-4d119b847809
      mkfs ext2 /dev/sda5 label:system-b
      mount /dev/sda5 /
      tar-in ${systemTarball} / compress:xz xattrs:true
      unmount /

      quit
    EOF
    echo "done."
  '';
}

