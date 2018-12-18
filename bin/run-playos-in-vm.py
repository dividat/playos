#!/usr/bin/env python

import tempfile
from contextlib import contextmanager
import subprocess
import os
import shutil

import time

VERSION = "@version@"
SYSTEM_TOP_LEVEL = "@toplevel@"
BINDFS_BIN = "@bindfs@"


@contextmanager
def system_partition(system):
    with tempfile.TemporaryDirectory(prefix="system-partition-") as sp:
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
            print("Destroying system partition")
            # TODO: Investigate where fusermount lives
            subprocess.run(["fusermount", "-u", sp + "/nix/store"])


def run_vm(system, qemu_opts=[]):
    default_qemu_opts = ['--enable-kvm', '-m', '2048']
    with system_partition(system) as sp:
        kernel = sp + '/kernel'
        kernel_arguments = 'boot.shell_on_panic'
        initrd = sp + '/initrd'
        virtfs_opts = 'local,path={},security_model=none,mount_tag=system,readonly'.format(
            sp)
        print("system partition at: {}".format(sp))
        print("Starting QEMU...")
        subprocess.run([
            'qemu-system-x86_64', '-kernel', kernel, '-initrd', initrd,
            '--virtfs', virtfs_opts, '-append', kernel_arguments
        ] + default_qemu_opts + qemu_opts)


run_vm(SYSTEM_TOP_LEVEL)
