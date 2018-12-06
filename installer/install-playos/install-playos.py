#!/usr/bin/env python

import subprocess
import os
import sys
import shutil
import argparse
import parted

PARTITION_SIZE_GB_SYSTEM=5
PARTITION_SIZE_GB_DATA=2

GRUB_CFG="@grubCfg@"
SYSTEM_TARBALL="@systemTarball@"
VERSION="@version@"


def findDevice(devicePath):
    """Return suitable device to install PlayOS on"""
    devices = parted.getAllDevices()
    device = None
    if devicePath == None:
        # Use the largest available disk
        try:
            device = sorted(parted.getAllDevices(),key=lambda d: d.length * d.sectorSize, reverse=True)[0]
        except IndexError:
            pass
    else:
        try:
            device = next(device for device in devices if device.path == devicePath)
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

def createPartitioning(device):
    """Returns a suitable partitioning (a disk) of the given
    device. You must specify device path (e.g. "/dev/sda"). Note that
    no changes will be made to the device. To write the partition to
    device use commit."""
    disk = parted.freshDisk(device, 'gpt')
    geometries = _computeGeometries(device)
    # Create ESP
    esp = parted.Partition(disk=disk,
                               type=parted.PARTITION_NORMAL,
                               fs=parted.FileSystem(type='fat32', geometry=geometries['esp']),
                               geometry=geometries['esp'])
    esp.setFlag(parted.PARTITION_BOOT)
    disk.addPartition(partition=esp, constraint=device.optimalAlignedConstraint)
    # Create Data partition
    data = parted.Partition(disk=disk,
                                type=parted.PARTITION_NORMAL,
                                fs=parted.FileSystem(type='ext4', geometry=geometries['data']),
                                geometry=geometries['data'])
    disk.addPartition(partition=data, constraint=device.optimalAlignedConstraint)
    # Create system.a partition
    systemA = parted.Partition(disk=disk,
                                type=parted.PARTITION_NORMAL,
                                fs=parted.FileSystem(type='ext4', geometry=geometries['systemA']),
                                geometry=geometries['systemA'])
    disk.addPartition(partition=systemA, constraint=device.optimalAlignedConstraint)
    # Create system.b partition
    systemB = parted.Partition(disk=disk,
                                type=parted.PARTITION_NORMAL,
                                fs=parted.FileSystem(type='ext4', geometry=geometries['systemB']),
                                geometry=geometries['systemB'])
    disk.addPartition(partition=systemB, constraint=device.optimalAlignedConstraint)
    return(disk)

def _computeGeometries(device):
    sectorSize = device.sectorSize
    esp = parted.Geometry(
        device=device,
        start=parted.sizeToSectors(8, "MB", sectorSize),
        length=parted.sizeToSectors(256, "MB", sectorSize))
    data = parted.Geometry(
        device=device,
        start=esp.end+1,
        length=parted.sizeToSectors(PARTITION_SIZE_GB_DATA, "GB", sectorSize))
    systemA = parted.Geometry(
        device=device,
        start=data.end+1,
        length=parted.sizeToSectors(PARTITION_SIZE_GB_SYSTEM, "GB", sectorSize))
    systemB = parted.Geometry(
        device=device,
        start=systemA.end+1,
        length=parted.sizeToSectors(PARTITION_SIZE_GB_SYSTEM, "GB", sectorSize))
    return {'esp': esp, 'data': data, 'systemA': systemA, 'systemB': systemB}
    
def installBootloader(disk):
    esp = disk.partitions[0]
    subprocess.run(['mkfs.vfat','-n','ESP',esp.path], check=True)
    os.makedirs('/mnt/boot', exist_ok=True)
    subprocess.run(['mount',esp.path,'/mnt/boot'], check=True)
    subprocess.run(['grub-install',
                        '--no-nvram',
                        '--no-bootsector',
                        '--removable',
                        '--boot-directory','/mnt/boot',
                        '--target','x86_64-efi',
                        '--efi-directory','/mnt/boot'], check=True)
    os.makedirs('/mnt/boot/grub/', exist_ok=True)
    shutil.copyfile(GRUB_CFG,'/mnt/boot/grub/grub.cfg')
    # TODO: set machineID
    # Unmount to make this function idempotent.
    subprocess.run(['umount','/mnt/boot'], check=True)

def _installSystem(partitionPath, label):
    subprocess.run(['mkfs.ext4',
                        '-F',
                        '-L', label,
                        partitionPath], check=True)
    os.makedirs('/mnt/system', exist_ok=True)
    subprocess.run(['mount',partitionPath,'/mnt/system'], check=True)
    subprocess.run(['tar','xfJ',SYSTEM_TARBALL,
                        '-C','/mnt/system'], check=True)
    subprocess.run(['umount','/mnt/system'])

def install(disk):
    dataPartition = disk.partitions[1]
    subprocess.run(['mkfs.ext4',
                        '-F',
                        '-L','data',
                        dataPartition.path], check=True)
    _installSystem(disk.partitions[2].path, 'system.a')
    _installSystem(disk.partitions[3].path, 'system.b')

# from http://code.activestate.com/recipes/577058/
def query_yes_no(question, default="no"):
    """Ask a yes/no question via raw_input() and return their answer.
    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
        It must be "yes" (the default), "no" or None (meaning
        an answer is required of the user).
    The "answer" return value is one of "yes" or "no".
    """
    valid = {"yes":"yes",   "y":"yes",  "ye":"yes",
                 "no":"no",     "n":"no"}
    if default == None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
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

def _deviceSizeInGB(device):
    return (device.sectorSize * device.length) / (10 ** 9)

def confirm(device, no_confirm):
    print('Installing PlayOS ({}) to {} ({} - {:n}GB)'
              .format(VERSION,
                          device.path,
                          device.model,
                          _deviceSizeInGB(device)))
    return (no_confirm or query_yes_no('Do you want to continue?'))

def _main(opts):
    
    device = findDevice(opts.device)
    
    if confirm(device, no_confirm=opts.no_confirm):
        # Create a partitioned disk
        disk = createPartitioning(device)
        # Write partition to disk. WARNING: This partitions your drive!
        commit(disk)
        # Install bootloader
        installBootloader(disk)
        # Install system
        install(disk)
        print("Done. Please reboot.")
        exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Install PlayOS")
    parser.add_argument('-v','--version',action='version',version=VERSION)
    parser.add_argument('--device',help='Device to install on (e.g. "/dev/sda"). If no device is specified a suitable device will be auto-detected.')
    parser.add_argument('--no-confirm',action='store_true',help="Do not ask for confirmation. WARNING: THIS WILL FORMAT THE INSTALLATION DEVICE WIHTOUT CONFIRMATION.")
    _main(parser.parse_args())


