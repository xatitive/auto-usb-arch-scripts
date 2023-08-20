#!/bin/bash

# init ---------------------------------------------------
# /dev/sdb
_drive=$1
_name=$2

# /dev/sdb1
_boot=${_drive}1
# EFI folder tends to require ~50mb
_bootsize=4G
# /dev/sdb2
_root=${_drive}2
# --------------------------------------------------------

# sanity checking ----------------------------------------
# exit on error
set -e
# make sure we're root
if [[ $EUID -ne 0 ]]; then
    echo "You must be a root user to run this." 2>&1
    exit 1
fi
# make sure drive exists
if [[ ! -b "${_drive}" ]]; then
    echo "Block device ${_drive} not found, or is not a block device!" 2>&1
    echo "Usage: ${0} /dev/sdX hostname" 2>&1
    exit 1
fi
# make sure _name exists
if [[ -z "${_name}" ]]; then
    echo "Usage: ${0} /dev/sdX hostname" 2>&1
    exit 1
fi 

if [[ -z "${_filetype}" ]]; then
    _filetype="ext4"
fi

# make sure specified drive isn't mounted anywhere
if [[ ! -z "$(cat /proc/mounts | grep ${_drive})" ]]; then
    echo "${_drive} must be unmounted before trying to run this!" 2>&1
    exit 1
fi
# make sure we have all our tools installed
if [[ -z "$( pacman -Q | grep dosfstools )" ]]; then
    pacman -S dosfstools --noconfirm
fi
if [[ -z "$( pacman -Q | grep exfat-utils )" ]]; then
    pacman -S exfat-utils --noconfirm
fi
if [[ -z "$( pacman -Q | grep exfat-utils )" ]]; then
    pacman -S exfat-utils --noconfirm
fi
if [[ -z "$( pacman -Q | grep arch-install-scripts )" ]]; then
    pacman -S arch-install-scripts --noconfirm
fi
# --------------------------------------------------------

# partition it -------------------------------------------
# We don't scriptify this so that user can get a warning that the drive is going bye-bye
parted ${_drive} mklabel gpt
# 1 efi and /boot
parted --script ${_drive} -a optimal mkpart ESP fat32 5M ${_bootsize}
# 2 /
parted --script ${_drive} -a optimal mkpart primary ext4 ${_bootsize} 100%

parted --script ${_drive} set 1 boot on
sync
# --------------------------------------------------------

# mkfs ---------------------------------------------------
# fat32 has no journaling I think
mkfs.vfat -F 32 -n BOOT ${_boot}
# -F forces mkfs to make a fs here
mkfs.ext4 -F -O ^has_journal ${_root}

sync

# --------------------------------------------------------

# mount it -----------------------------------------------
mount ${_root} -o noatime /mnt
mkdir /mnt/boot
mount ${_boot} /mnt/boot
# --------------------------------------------------------

# install it ---------------------------------------------
t2strap /mnt base linux-firmware iwd grub efibootmgr    
# --------------------------------------------------------

# configure it -------------------------------------------
genfstab -U /mnt >> /mnt/etc/fstab
cp $(pwd)/configure.sh /mnt
chmod +x /mnt/configure.sh
arch-chroot /mnt /configure.sh ${_drive} ${_name}
rm /mnt/configure.sh
# --------------------------------------------------------

echo "All done! Attemping unmount..."

# finish up!
sync
umount ${_boot}
umount ${_root}
sync

echo "You may now remove the USB."
