{config, ...}:
{
    config = {
        # Disable ext4 features that are not supported by older GRUB versions,
        # used by in PlayOS installations up to and including version 2023.2.0.
        # See: https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/1844012
        # Debian patch: https://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git/commit/?h=debian/master&id=1181f164c48574a4813bfa203dbd7b4123154021
        environment.sessionVariables.MKE2FS_CONFIG = "/etc/mke2fs.conf";

        # Ensure any process started by systemd has this in the config, in
        # particular system services such as RAUC
        environment.etc."systemd/system.conf.d/default-env.conf".text = ''
            [Manager]
            DefaultEnvironment="MKE2FS_CONFIG=/etc/mke2fs.conf"
        '';

        environment.etc."mke2fs.conf" = {
            # Default e2fsprogs v1.47.3 mke2fs.conf with two modifications:
            # metadata_csum_seed and orphan_file are set to disabled in ext4
            # source: https://github.com/tytso/e2fsprogs/blob/v1.47.3/misc/mke2fs.conf.in
            source = ./mke2fs.conf;
        };
    };
}
