#!/bin/bash

#This simply runs the chroot_commands script, which was created in the earlier step, under chroot mode
#The called script changes grub configuration

set -x

#Change the mode to executable
chmod +x /mnt/tmp/chroot_commands.sh

mount --bind /proc /mnt/proc
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys

#Run this script in chroot mode
chroot /mnt ./tmp/grub_configure.sh

umount -l /mnt
