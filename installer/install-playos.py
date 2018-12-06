#!/usr/bin/env python
import subprocess
import os
import shutil
import parted

PARTITION_SIZE_GB_SYSTEM=5
PARTITION_SIZE_GB_DATA=2

GRUB_CFG="@grubCfg@"
SYSTEM_TARBALL="@systemTarball@"


def _to_gigabytes(value):
    return value / (10 ** 9)

def availableDevices():
    devices = map(lambda device:
                      { 'model': device.model,
                        'path': device.path,
                        'sizeInGB': _to_gigabytes(device.sectorSize * device.length)},
                      parted.getAllDevices())
    return devices

def commit(disk):
    """Commit disk partitioning. WARNING: This will make any data on
    device unaccessible."""
    disk.commit()

def createPartitioning(devicePath):
    """Returns a suitable partitioning (a disk) of the given
    device. You must specify device path (e.g. "/dev/sda"). Note that
    no changes will be made to the device. To write the partition to
    device use commit."""
    device = parted.getDevice(devicePath)
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
                        

# Create a partitioned disk
disk = createPartitioning('/dev/vda')

# Write partition to disk. WARNING: This partitions your drive!
commit(disk)

# Install bootloader
installBootloader(disk)

# Install system
install(disk)

