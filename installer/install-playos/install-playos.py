#!@python@/bin/python

import subprocess
import os
import sys
import shutil
import argparse
import json
import parted
import uuid
import configparser
import re
from datetime import datetime

DEFAULT_PARTITION_SIZE_GB_SYSTEM = 10
DEFAULT_PARTITION_SIZE_GB_DATA = 5

GRUB_CFG = "@grubCfg@"
GRUB_ENV = '/mnt/boot/grub/grubenv'
SYSTEM_IMAGE = "@systemImage@"
RESCUE_SYSTEM = "@rescueSystem@"
SYSTEM_CLOSURE_INFO = "@systemClosureInfo@"
VERSION = "@version@"

PLAYOS_UPDATE_URL = "@updateUrl@"
PLAYOS_KIOSK_URL = "@kioskUrl@"

def find_device(device_path, part_sizes):
    """Return suitable device to install PlayOS on"""
    all_devices = parted.getAllDevices()

    print(f"Found {len(all_devices)} disk devices:")
    for device in all_devices:
        print(f'\t{device_info(device)}')

    required_install_device_size_gb = part_sizes['data'] + 2*part_sizes['system'] + 1

    # We want to avoid installing to the installer medium, so we filter out
    # devices from the boot disk. We use the fact that we mount from the
    # installer medium at `/iso`.
    boot_device = get_blockdevice("/iso")
    if boot_device is None:
        print("Could not identify installer medium. Considering all disks as installation targets.")

    def device_filter(dev):
        is_boot_device = (boot_device is not None) and dev.path.startswith(boot_device)
        is_read_only = dev.readOnly
        is_big_enough = gb_size(dev) > required_install_device_size_gb

        return (not is_boot_device) and (not is_read_only) and is_big_enough

    available_devices = [device for device in all_devices if device_filter(device)]

    print("Minimum required size for installation target: {req_gb} GB".format(
        req_gb=required_install_device_size_gb
    ))
    
    print(f"Found {len(available_devices)} possible installation targets:")
    for device in available_devices:
        print(f'\t{device_info(device)}')

    device = None
    if device_path is None:
        # Use the largest available disk
        try:
            device = sorted(
                available_devices,
                key=lambda d: d.length * d.sectorSize,
                reverse=True)[0]
        except IndexError:
            pass
    else:
        try:
            device = next(
                device for device in all_devices if device.path == device_path)
        except StopIteration:
            pass

    return device


def get_blockdevice(mount_path):
    """Find the block device path for a given mountpoint."""
    result = subprocess.run(['lsblk', '-J'], capture_output=True, text=True)
    lsblk_data = json.loads(result.stdout)

    # Find the parent device of the partition with mountpoint
    for device in lsblk_data['blockdevices']:
        if 'children' in device:
            children = device['children']
        # the mount could be e.g. a cdrom blockdevice, in which case there are
        # no cildren
        else:
            children = [device]

        for child in children:
            if 'mountpoints' in child and mount_path in child['mountpoints']:
                return '/dev/' + device['name']
    return None

def gb_size(device):
    return int((device.sectorSize * device.length) / (10**9))

def device_info(device):
    return f'{device.path} ({device.model} - {gb_size(device)} GB)'


def commit(disk):
    """Commit disk partitioning. WARNING: This will make any data on
    device unaccessible."""
    disk.commit()


def create_partitioning(device, part_sizes):
    """Returns a suitable partitioning (a disk) of the given
    device. You must specify device path (e.g. "/dev/sda"). Note that
    no changes will be made to the device. To write the partition to
    device use commit."""
    disk = parted.freshDisk(device, 'gpt')
    geometries = _compute_geometries(device, part_sizes)
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


def _compute_geometries(device, part_sizes):
    sectorSize = device.sectorSize
    esp = parted.Geometry(
        device=device,
        start=parted.sizeToSectors(8, "MB", sectorSize),
        length=parted.sizeToSectors(550, "MB", sectorSize))
    data = parted.Geometry(
        device=device,
        start=esp.end + 1,
        length=parted.sizeToSectors(part_sizes['data'], "GB", sectorSize))
    systemA = parted.Geometry(
        device=device,
        start=data.end + 1,
        length=parted.sizeToSectors(part_sizes['system'], "GB",
                                    sectorSize))
    systemB = parted.Geometry(
        device=device,
        start=systemA.end + 1,
        length=parted.sizeToSectors(part_sizes['system'], "GB",
                                    sectorSize))
    return {'esp': esp, 'data': data, 'systemA': systemA, 'systemB': systemB}


def install_bootloader(disk, machine_id):
    """ Install bootloader and rescue system
    """
    esp = disk.partitions[0]
    subprocess.run(['mkfs.vfat', '-n', 'ESP', esp.path], check=True)
    os.makedirs('/mnt/boot', exist_ok=True)
    subprocess.run(['mount', esp.path, '/mnt/boot'], check=True)
    _suppress_unless_fails(
        subprocess.run(
            [
                'grub-install', '--no-nvram', '--no-bootsector', '--removable',
                '--boot-directory', '/mnt/boot', '--target', 'x86_64-efi',
                '--efi-directory', '/mnt/boot'
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE))
    os.makedirs('/mnt/boot/grub/', exist_ok=True)
    shutil.copy2(GRUB_CFG, '/mnt/boot/grub/grub.cfg')
    subprocess.run(
        ['grub-editenv', GRUB_ENV, 'set', 'machine_id=' + machine_id.hex],
        check=True)

    # Install the rescue system
    os.makedirs('/mnt/boot/rescue', exist_ok=True)
    shutil.copy2(RESCUE_SYSTEM + '/kernel', '/mnt/boot/rescue/kernel')
    shutil.copy2(RESCUE_SYSTEM + '/initrd', '/mnt/boot/rescue/initrd')

    # Unmount to make this function idempotent.
    subprocess.run(['umount', '/mnt/boot'], check=True)


def add_rauc_status_entries(esp, slot_name):
    """ Add metadata about installation to status.ini file """
    # Mount ESP
    subprocess.run(['mount', esp, '/mnt/boot'], check=True)

    # Read existing status file
    status = configparser.ConfigParser()
    status.read('/mnt/boot/status.ini')

    # Add version and installation timestamp
    status["slot." + slot_name] = {
        'bundle.version': VERSION,
        'installed.timestamp': datetime.now().isoformat()
    }

    # Write status file
    with open('/mnt/boot/status.ini', 'w') as status_file:
        status.write(status_file)

    # Unmount ESP
    subprocess.run(['umount', '/mnt/boot'], check=True)


def install_system(partitionPath, label):
    """ Create filesystem on system partition and copy nix store plus toplevel files
    """

    # Create filesystem
    subprocess.run(['mkfs.ext4', '-F', '-L', label, partitionPath], check=True)

    # Mount system partition
    os.makedirs('/mnt/system', exist_ok=True)
    subprocess.run(['mount', partitionPath, '/mnt/system'], check=True)

    # Copy Nix store content
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

    # Copy kernel, initrd and init
    subprocess.run(
        ['cp', '-av', SYSTEM_IMAGE + '/kernel', '/mnt/system/kernel'],
        check=True)
    subprocess.run(
        ['cp', '-av', SYSTEM_IMAGE + '/initrd', '/mnt/system/initrd'],
        check=True)
    subprocess.run(
        ['cp', '-av', SYSTEM_IMAGE + '/init', '/mnt/system/init'],
        check=True)

    # Unmount system partition
    subprocess.run(['umount', '/mnt/system'])


def install(disk):
    """ Install to already partitioned disk """
    # Create data partition filesystem
    dataPartition = disk.partitions[1]
    subprocess.run(
        ['mkfs.ext4', '-F', '-L', 'data', dataPartition.path], check=True)

    # Install system.a
    install_system(disk.partitions[2].path, 'system.a')
    add_rauc_status_entries(disk.partitions[0].path, 'system.a')

    # Install system.b
    install_system(disk.partitions[3].path, 'system.b')
    add_rauc_status_entries(disk.partitions[0].path, 'system.b')


def _suppress_unless_fails(completed_process):
    """Suppress the stdout of a subprocess unless it fails.
    Additional parameters {stdout,stderr}=subprocess.PIPE to
    subprocess.run are required."""
    try:
        completed_process.check_returncode()
    except:
        sys.stdout.write(completed_process.stdout)
        sys.stdout.write(completed_process.stderr)
        raise


# from http://code.activestate.com/recipes/577058/
def _query_continue(question, default=False):
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default is True:
        prompt = " [Y/n] "
    elif default is False:
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


def _ensure_machine_id(passed_machine_id, device):
    if passed_machine_id is None:
        previous_machine_id = _get_grubenv_entry('machine_id', device)
        if previous_machine_id is None:
            return uuid.uuid4()
        else:
            return uuid.UUID(previous_machine_id)
    else:
        return uuid.UUID(passed_machine_id)


def _get_grubenv_entry(entry_name, device):
    try:
        # Try to mount the device's first partition
        disk = parted.newDisk(device)
        esp = disk.partitions[0]
        os.makedirs('/mnt/boot', exist_ok=True)
        subprocess.run(['mount', esp.path, '/mnt/boot'],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)
        # Try to read entry from grubenv
        grub_list = subprocess.run(
            ['grub-editenv', GRUB_ENV, 'list'],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            universal_newlines=True)
        entry_match = re.search("^" + entry_name + "=(.+)$", grub_list.stdout,
                                re.MULTILINE)
        if entry_match is None:
            return None
        else:
            return entry_match.group(1)
    except:
        return None
    finally:
        subprocess.run(['umount', '/mnt/boot'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)


def confirm(device, machine_id, no_confirm):
    print('\n\nInstalling PlayOS ({}) to {}'.format(VERSION, device_info(device)))
    print('  Machine ID: {}'.format(machine_id.hex))
    print('  Update URL: {}'.format(PLAYOS_UPDATE_URL))
    print('  Kiosk URL: {}\n'.format(PLAYOS_KIOSK_URL))
    return (no_confirm or _query_continue('Do you want to continue?'))


def _main(opts):
    # sizes in GB
    part_sizes = {
        'system': opts.partition_size_system,
        'data': opts.partition_size_data,
    }
    # Detect device to install to
    device = find_device(opts.device, part_sizes)
    if device is None:
        print('\nNo suitable device to install on found.')
        exit(1)

    # Ensure machine-id exists and is valid
    machine_id = _ensure_machine_id(opts.machine_id, device)

    # Confirm installation
    if confirm(device, machine_id, no_confirm=opts.no_confirm):

        # Create a partitioned disk
        disk = create_partitioning(device, part_sizes)

        # Write partition to disk. WARNING: This partitions your drive!
        commit(disk)

        # Install bootloader
        install_bootloader(disk, machine_id)

        # Install system
        install(disk)

        # And optionally reboot system
        if opts.reboot:
            subprocess.run(['reboot'])
        else:
            print('\nDone. Please remove install medium and reboot.')

        exit(0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Install PlayOS",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
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
        'Set system machine-id. If not specified, an already configured id will be reused, or a random id will be generated'
    )
    part_args = parser.add_argument_group('partitioning', 'Partitioning options')
    part_args.add_argument(
        '--partition-size-system',
        type=int,
        default=DEFAULT_PARTITION_SIZE_GB_SYSTEM,
        help='Size of the system partitions, in GB'
    )
    part_args.add_argument(
        '--partition-size-data',
        type=int,
        default=DEFAULT_PARTITION_SIZE_GB_DATA,
        help='Size of the data partition, in GB'
    )
    _main(parser.parse_args())
