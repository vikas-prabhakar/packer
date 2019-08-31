#!/bin/bash
set -x
#Replace 'GRUB_CMDLINE_LINUX=""' line in /etc/default/grub

sed -i 's/GRUB_CMDLINE_LINUX\=\"\"/GRUB_CMDLINE_LINUX\=\"console\=ttyS0,115200n8 console\=tty0 net.ifnames\=0 crashkernel\=auto rd.lvm.lv\=vg_sys\/lvroot root\=\/dev\/mapper\/vg_sys-lv_root\"/' /etc/default/grub

#Add the below line after 'GRUB_TERMINAL=console' in /etc/default/grub
sed -i '/GRUB_PRELOAD_MODULES\=lvm/a GRUB_PRELOAD_MODULES\=lvm' /etc/default/grub

#Update the initramfs

update-initramfs -c -k `uname -r`

#Update grub2

update-grub2 -o /boot/grub/grub.cfg

#Install LVM related modules 
grub-install --modules 'part_gpt part_msdos lvm' /dev/xvdf

dd if=/dev/xvdf of=boot.bin bs=512 count=1
exit
