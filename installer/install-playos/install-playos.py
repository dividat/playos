#!/usr/bin/env python

import subprocess
import os
import sys
import shutil
import argparse
import parted
import uuid

PARTITION_SIZE_GB_SYSTEM = 5
PARTITION_SIZE_GB_DATA = 2

GRUB_CFG = "@grubCfg@"
SYSTEM_TOP_LEVEL = "@systemToplevel@"
RESUCE_SYSTEM = "@rescueSystem@"
SYSTEM_CLOSURE_INFO = "@systemClosureInfo@"
VERSION = "@version@"


def find_device(device_path):
    """Return suitable device to install PlayOS on"""
    devices = parted.getAllDevices()
    device = None
    if device_path == None:
        # Use the largest available disk
        try:
            device = sorted(
                parted.getAllDevices(),
                key=lambda d: d.length * d.sectorSize,
                reverse=True)[0]
        except IndexError:
            pass
    else:
        try:
            device = next(
                device for device in devices if device.path == device_path)
        except StopIteration:
            pass
    if device == None:
        raise ValueError('No suitable device to install on found.')
    else:
        return device


def commit(disk):
    """Commit disk partitioning. WARNING: This will make any data on
    device unaccessible."""
    disk.commit()


def create_partitioning(device):
    """Returns a suitable partitioning (a disk) of the given
    device. You must specify device path (e.g. "/dev/sda"). Note that
    no changes will be made to the device. To write the partition to
    device use commit."""
    disk = parted.freshDisk(device, 'gpt')
    geometries = _compute_geometries(device)
    # Create ESP
    esp = parted.Partition(
        disk=disk,
        type=parted.PARTITION_NORMAL,
        fs=parted.FileSystem(type='fat32', geometry=geometries['esp']),
        geometry=geometries['esp'])
    esp.setFlag(parted.PARTITION_BOOT)
    disk.addPartition(
        partition=esp, constraint=device.optimalAlignedConstraint)
    # Create Data partition
    data = parted.Partition(
        disk=disk,
        type=parted.PARTITION_NORMAL,
        fs=parted.FileSystem(type='ext4', geometry=geometries['data']),
        geometry=geometries['data'])
    disk.addPartition(
        partition=data, constraint=device.optimalAlignedConstraint)
    # Create system.a partition
    systemA = parted.Partition(
        disk=disk,
        type=parted.PARTITION_NORMAL,
        fs=parted.FileSystem(type='ext4', geometry=geometries['systemA']),
        geometry=geometries['systemA'])
    disk.addPartition(
        partition=systemA, constraint=device.optimalAlignedConstraint)
    # Create system.b partition
    systemB = parted.Partition(
        disk=disk,
        type=parted.PARTITION_NORMAL,
        fs=parted.FileSystem(type='ext4', geometry=geometries['systemB']),
        geometry=geometries['systemB'])
    disk.addPartition(
        partition=systemB, constraint=device.optimalAlignedConstraint)
    return (disk)


def _compute_geometries(device):
    sectorSize = device.sectorSize
    esp = parted.Geometry(
        device=device,
        start=parted.sizeToSectors(8, "MB", sectorSize),
        length=parted.sizeToSectors(550, "MB", sectorSize))
    data = parted.Geometry(
        device=device,
        start=esp.end + 1,
        length=parted.sizeToSectors(PARTITION_SIZE_GB_DATA, "GB", sectorSize))
    systemA = parted.Geometry(
        device=device,
        start=data.end + 1,
        length=parted.sizeToSectors(PARTITION_SIZE_GB_SYSTEM, "GB",
                                    sectorSize))
    systemB = parted.Geometry(
        device=device,
        start=systemA.end + 1,
        length=parted.sizeToSectors(PARTITION_SIZE_GB_SYSTEM, "GB",
                                    sectorSize))
    return {'esp': esp, 'data': data, 'systemA': systemA, 'systemB': systemB}


def install_bootloader(disk, machine_id):
    esp = disk.partitions[0]
    subprocess.run(['mkfs.vfat', '-n', 'ESP', esp.path], check=True)
    os.makedirs('/mnt/boot', exist_ok=True)
    subprocess.run(['mount', esp.path, '/mnt/boot'], check=True)
    subprocess.run(
        [
            'grub-install', '--no-nvram', '--no-bootsector', '--removable',
            '--boot-directory', '/mnt/boot', '--target', 'x86_64-efi',
            '--efi-directory', '/mnt/boot'
        ],
        check=True)
    os.makedirs('/mnt/boot/grub/', exist_ok=True)
    shutil.copy2(GRUB_CFG, '/mnt/boot/grub/grub.cfg')
    subprocess.run(
        [
            'grub-editenv', '/mnt/boot/grub/grubenv', 'set',
            'machine_id=' + machine_id.hex
        ],
        check=True)

    # Install the rescue system
    os.makedirs('/mnt/boot/rescue', exist_ok=True)
    shutil.copy2(RESUCE_SYSTEM + '/kernel', '/mnt/boot/rescue/kernel')
    shutil.copy2(RESUCE_SYSTEM + '/initrd', '/mnt/boot/rescue/initrd')

    # Unmount to make this function idempotent.
    subprocess.run(['umount', '/mnt/boot'], check=True)


def _install_system(partitionPath, label):
    subprocess.run(['mkfs.ext4', '-F', '-L', label, partitionPath], check=True)
    os.makedirs('/mnt/system', exist_ok=True)
    subprocess.run(['mount', partitionPath, '/mnt/system'], check=True)
    os.makedirs('/mnt/system/nix/store', exist_ok=True)
    with open(SYSTEM_CLOSURE_INFO + '/store-paths', 'r') as store_paths_file:
        store_paths = store_paths_file.read().splitlines()
        # Using tar is faster than cp
        read = subprocess.Popen(
            ['tar', 'cf', '-'] + store_paths, stdout=subprocess.PIPE)
        status = subprocess.Popen(
            ['pv'], stdin=read.stdout, stdout=subprocess.PIPE)
        write = subprocess.run(
            ['tar', 'xf', '-', '-C', '/mnt/system'],
            check=True,
            stdin=status.stdout)
        read.wait()
    subprocess.run(
        ['cp', '-av', SYSTEM_TOP_LEVEL + '/initrd', '/mnt/system/initrd'],
        check=True)
    subprocess.run(
        ['cp', '-av', SYSTEM_TOP_LEVEL + '/kernel', '/mnt/system/kernel'],
        check=True)
    subprocess.run(
        ['cp', '-av', SYSTEM_TOP_LEVEL + '/init', '/mnt/system/init'],
        check=True)
    subprocess.run(['umount', '/mnt/system'])


def install(disk):
    dataPartition = disk.partitions[1]
    subprocess.run(
        ['mkfs.ext4', '-F', '-L', 'data', dataPartition.path], check=True)
    _install_system(disk.partitions[2].path, 'system.a')
    _install_system(disk.partitions[3].path, 'system.b')


# from http://code.activestate.com/recipes/577058/
def _query_continue(question, default=False):
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default == None:
        prompt = " [y/n] "
    elif default == True:
        prompt = " [Y/n] "
    elif default == False:
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)
    while 1:
        sys.stdout.write(question + prompt)
        choice = input().lower()
        if default is not None and choice == '':
            return default
        elif choice in valid.keys():
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no'")


def _ensure_machine_id(machine_id):
    if machine_id == None:
        return uuid.uuid4()
    else:
        return uuid.UUID(machine_id)


def _device_size_in_gb(device):
    return (device.sectorSize * device.length) / (10**9)


def confirm(device, machine_id, no_confirm):
    print('\n\nInstalling PlayOS ({}) to {} ({} - {:n}GB)'.format(
        VERSION, device.path, device.model, _device_size_in_gb(device)))
    print('  machine-id: {}\n'.format(machine_id.hex))
    return (no_confirm or _query_continue('Do you want to continue?'))


def _main(opts):
    device = find_device(opts.device)
    machine_id = _ensure_machine_id(opts.machine_id)
    if confirm(device, machine_id, no_confirm=opts.no_confirm):
        # Create a partitioned disk
        disk = create_partitioning(device)
        # Write partition to disk. WARNING: This partitions your drive!
        commit(disk)
        # Install bootloader
        install_bootloader(disk, machine_id)
        # Install system
        install(disk)
        if opts.reboot:
            subprocess.run(['reboot'])
        else:
            print("Done. Please reboot.")
        exit(0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Install PlayOS")
    parser.add_argument('-v', '--version', action='version', version=VERSION)
    parser.add_argument(
        '--device',
        help=
        'Device to install on (e.g. "/dev/sda"). If no device is specified a suitable device will be auto-detected.'
    )
    parser.add_argument(
        '--no-confirm',
        action='store_true',
        help=
        "Do not ask for confirmation. WARNING: THIS WILL FORMAT THE INSTALLATION DEVICE WIHTOUT CONFIRMATION."
    )
    parser.add_argument(
        '--reboot',
        action='store_true',
        help="Reboot system automatically after installation")
    parser.add_argument(
        '--machine-id',
        help=
        'Set system machine-id. If not specified a random id will be generated'
    )
    _main(parser.parse_args())
