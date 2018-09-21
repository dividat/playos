{ stdenv
, libguestfs
, name ? "disk-image.img"
, systemTarball
, espTarball
}:
stdenv.mkDerivation {
  inherit name;

  buildInputs = [
    libguestfs
  ];

  phases = [ "buildPhase" ];

  buildPhase = ''
    export LIBGUESTFS_PATH=${libguestfs}/lib/guestfs
    guestfish -N $out=bootroot:vfat:ext2:2000M:512M:efi \
      set-label /dev/sda2 "nixos" : \
      set-label /dev/sda1 "ESP" : \
      mount /dev/sda2 / : \
      tar-in ${systemTarball} / compress:xz xattrs:true : \
      unmount / : \
      mount /dev/sda1 / :\
      tar-in ${espTarball} / compress:xz xattrs:true : \
      unmount / : \
      quit
  '';
}

