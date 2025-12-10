{config, ...}:
{
    config = {
        # Disable an ext4 feature that is not supported by older GRUB versions,
        # used by in PlayOS installations up to and including version 2023.2.0.
        # See: https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/1844012
        environment.etc."mke2fs.conf" = { text = ''
            [fs_types]
                ext4 = {
                    features = ^metadata_csum_seed
                }
        ''; };
    };
}
