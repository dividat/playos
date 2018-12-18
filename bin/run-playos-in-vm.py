#!/usr/bin/env python

import tempfile
from contextlib import contextmanager
import subprocess
import os
import stat
import shutil
import argparse

VERSION = "@version@"
SYSTEM_TOP_LEVEL = "@toplevel@"
DISK = "@disk@"
OVMF = "@ovmf@"

# Tools
BINDFS_BIN = "@bindfs@/bin/bindfs"
QEMU_SYSTEM_X86_64 = "@qemu@/bin/qemu-system-x86_64"
QEMU_IMG = "@qemu@/bin/qemu-img"

DEFAULT_QEMU_OPTS = ['--enable-kvm', '-m', '2048']

# set DISK to None if not substituted
if not os.path.isfile(DISK):
    DISK = None


@contextmanager
def system_partition(system):
    with tempfile.TemporaryDirectory(prefix="playos-system-partition-") as sp:
        try:
            os.makedirs(sp + "/nix/store")
            subprocess.run(
                [
                    BINDFS_BIN, "--no-allow-other", "/nix/store",
                    sp + "/nix/store"
                ],
                check=True)
            shutil.copy2(system + "/kernel", sp + "/kernel")
            shutil.copy2(system + "/initrd", sp + "/initrd")
            shutil.copy2(system + "/init", sp + "/init")
            yield sp
        finally:
            # TODO: Investigate where fusermount lives
            subprocess.run(["fusermount", "-u", sp + "/nix/store"])


def run_vm(system, qemu_opts=DEFAULT_QEMU_OPTS):
    with system_partition(system) as sp:
        kernel = sp + '/kernel'
        kernel_arguments = 'boot.shell_on_panic'
        initrd = sp + '/initrd'
        virtfs_opts = 'local,path={},security_model=none,mount_tag=system,readonly'.format(
            sp)
        print("system partition at: {}".format(sp))
        _qemu([
            '-kernel', kernel, '-initrd', initrd, '--virtfs', virtfs_opts,
            '-append', kernel_arguments
        ] + qemu_opts)


@contextmanager
def disk_overlay(disk):
    with tempfile.TemporaryDirectory(prefix='playos-disk-overlay-') as temp:
        # Create a disk overlay
        subprocess.run(
            [
                QEMU_IMG, 'create', '-f', 'qcow2', '-o'
                'backing_file={}'.format(disk), temp + "/disk-overlay.qcow2"
            ],
            check=True)

        # Copy NVRAM and make writeable
        shutil.copy2(OVMF, temp + "/OVMF.fd")
        os.chmod(temp + "/OVMF.fd", stat.S_IREAD | stat.S_IWRITE)

        try:
            yield temp
        finally:
            pass


def run_disk(disk, qemu_opts=DEFAULT_QEMU_OPTS):
    with disk_overlay(disk) as overlay:
        print("disk overlay at {}".format(overlay))
        _qemu(['-pflash', overlay + '/OVMF.fd'] + qemu_opts +
              [overlay + '/disk-overlay.qcow2'])
        input()


def _qemu(opts):
    try:
        print("Staring QEMU.")
        subprocess.run([QEMU_SYSTEM_X86_64] + opts, check=True)
    except KeyboardInterrupt:
        pass


def main(opts):
    if opts.disk:
        if DISK:
            run_disk(DISK)
        else:
            print("ERROR: disk not built.")
            exit(1)
    else:
        run_vm(SYSTEM_TOP_LEVEL)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Run PlayOS in a Virtual Machine.",
        epilog=
        "By default a system is started with testing instrumentation activated. This testing system does not boot via GRUB and has no disks attached. This is useful for rapidly testing higher-level system configurations. If you want to test lower-level system components use the '--disk' option which will start a system without test instrumentation."
    )
    parser.add_argument('-v', '--version', action='version', version=VERSION)
    parser.add_argument(
        '-d',
        '--disk',
        action='store_true',
        help="Use disk with full system. Requires the disk to have been built."
    )
    main(parser.parse_args())
