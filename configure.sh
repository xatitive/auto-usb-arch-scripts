#!/bin/bash

# configure.sh: This script is ran on the target host in order to configure it,
#               it recieves the drive node location (/dev/sdb) and the system
#               name as parameters.

_drive=$1
_name=$2

_journalsize=8M

_grub="quiet splash intel_iommu=on iommu=pt pcie_ports=compat"

_module="apple-bce"

# Set up hostname
echo ${_name} > /etc/hostname

# Then generate utf-8 english locales
sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Install efi bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub --recheck
# Now copy the grub bootloader to a special place
# Some motherboards automatically boot from the special place.
sed -i "s/GRUB_CMDLINE_LINUX=\"\"/$_grub/" /etc/default/grub
mkdir -p /boot/EFI/boot
cp /boot/EFI/grub/grubx64.efi /boot/EFI/boot/bootx64.efi
grub-mkconfig -o /boot/grub/grub.cfg

# Enable some services we'll need.
systemctl enable NetworkManager

# add apple-bce module to mkinitcpio
sed -i "s/MODULES=()/MODULES=($_modules)/" mkinitcpio.conf
mkinitcpio -p linux

# We need some user input here, don't want to be passwordless
echo "Setting root password..."
passwd
echo "Enter new user name:"
read _user
useradd -m -g users -G wheel -s /bin/bash ${_user}
echo "Setting ${_user}'s password:"
echo "${_user} has sudo access."
passwd ${_user}

echo "Configuration complete."

# Done!
