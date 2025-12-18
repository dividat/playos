# Similarly to testing/disk/default.nix, this builds a disk image containing
# a full PlayOS installation, with these differences:
# - It uses default system and boot partition sizes. Total disk size is ~20 GiB
# - It produces a (sparsified) qcow2 image rather than a raw one. This reduces
#   the image size to ~8GiB
# - It compresses the final image using zstd to reduce disk usage.
#   Final compressed file size is around ~4GiB.
{ pkgs
, lib
, install-playos
}:
with pkgs;
with lib;
let
  # all sizes in MiB
  partSizes = {
    boot = 525; # 525 MiB (matches install-playos default)
    system = 1024 * 9;  # 9 GiB (install-playos default - 1GiB)
    data = 2000; # 2000 MiB (same as testing/disk/default.nix)
  };
  diskSizeMiB = 8 + partSizes."boot" + partSizes."data" + (partSizes."system" * 2) + 1;
in
vmTools.runInLinuxVM (
  runCommand "build-playos-release-disk"
    {
      buildInputs = [install-playos];

      preVM = ''
        diskImage=nixos.raw
        truncate -s ${toString diskSizeMiB}MiB $diskImage
      '';

      postVM = ''
        mkdir -p $out
        ${pkgs.qemu}/bin/qemu-img convert -f raw -O qcow2 $diskImage $out/playos-disk.img
        rm $diskImage
        ${pkgs.zstd}/bin/zstd --rm -f $out/playos-disk.img -o $out/playos-disk.img.zst
        diskImage=$out/playos-disk.img.zst
      '';
      memSize = 1024;
    }
    ''
      # machine-id of development image is hardcoded.
      install-playos \
        --device /dev/vda \
        --machine-id "f414cca8312548d29689ebf287fb67e0" \
        --partition-size-boot ${toString partSizes."boot"} \
        --partition-size-system ${toString partSizes."system"} \
        --partition-size-data ${toString partSizes."data"} \
        --no-confirm
    ''
) + "/playos-disk.img.zst"
