#!/bin/bash

#This script has logic to create partitions volume groups and logical volumes
#Ultimately this has to go into the salt state that will be run through packer.


set -x

#Set variables, dev for EBS volume attach, change this if you change in the packer template the EBS volume you attach
#Mountpoint, mntpoint variable is the directory where the different mounts and directory will be create in the new volume
readonly local dev="/dev/xvdf"
readonly local mntpoint="/mnt"

 [ ! -d "${mntpoint}" ] && \
 errx "cannot find mountpoint '${mntpoint}'"

#Create partitions using parted in {dev}
#Will be creating two partitions
#1 for boot {dev}1
#2 for creating volume group and logical volumes

 parted -a optimal "${dev}" mklabel msdos print || \
 exit 1
 parted -a optimal "${dev}" mkpart primary '0%' '1%' set 1 boot on print || \
 exit 1
 parted -a optimal "${dev}" mkpart primary '1%' '100%' set 2 lvm on print || \
 exit 1

#Create a new LVM volume on the second EBS volume {dev}2

pvcreate ${dev}2
vgcreate vg_sys ${dev}2

#Create logical volumes from volume group created

lvcreate -L 15G -n lv_root vg_sys
lvcreate -L 15G -n lv_var vg_sys
lvcreate -L 15G -n lv_varlog vg_sys
lvcreate -L 5G -n lv_varlogaudit vg_sys
lvcreate -L 4G -n lv_vartmp vg_sys
lvcreate -L 6G -n lv_tmp vg_sys
lvcreate -L 10G -n lv_home vg_sys
lvcreate -L 4G  -n lv_swap vg_sys

#Make new EXT4 file system on Logical volume

mkfs.ext4 /dev/mapper/vg_sys-lv_varlogaudit
mkfs.ext4 /dev/mapper/vg_sys-lv_root
mkfs.ext4 /dev/mapper/vg_sys-lv_vartmp
mkfs.ext4 /dev/mapper/vg_sys-lv_var
mkfs.ext4 /dev/mapper/vg_sys-lv_varlog
mkfs.ext4 /dev/mapper/vg_sys-lv_tmp
mkfs.ext4 /dev/mapper/vg_sys-lv_home
mkswap /dev/mapper/vg_sys-lv_swap


#Tunable filesystem parameters on ext2/ext3/ext4 filesystems

tune2fs -m 0 /dev/mapper/vg_sys-lv_varlogaudit
tune2fs -m 0 /dev/mapper/vg_sys-lv_root
tune2fs -m 0 /dev/mapper/vg_sys-lv_vartmp
tune2fs -m 0 /dev/mapper/vg_sys-lv_var
tune2fs -m 0 /dev/mapper/vg_sys-lv_varlog
tune2fs -m 0 /dev/mapper/vg_sys-lv_tmp
tune2fs -m 0 /dev/mapper/vg_sys-lv_home


#Create ${mntpoint}/* directory and mount it to logical volumes created

mount /dev/mapper/vg_sys-lv_root ${mntpoint}/

mkdir -p ${mntpoint}/var ${mntpoint}/tmp  ${mntpoint}/home 
mount /dev/mapper/vg_sys-lv_var ${mntpoint}/var
mkdir -p  ${mntpoint}/var/tmp
mount /dev/mapper/vg_sys-lv_varlog ${mntpoint}/var/log
mount /dev/mapper/vg_sys-lv_home ${mntpoint}/home
mount /dev/mapper/vg_sys-lv_tmp ${mntpoint}/tmp
mkdir -p ${mntpoint}/var/tmp
mount /dev/mapper/vg_sys-lv_vartmp ${mntpoint}/var/tmp
mkdir -p ${mntpoint}/var/log/audit
mount /dev/mapper/vg_sys-lv_varlogaudit ${mntpoint}/var/log/audit
swapon -v /dev/vg_sys/lv_swap

#Copy the data from the root volume to the Logical volume

rsync -avxHAX --progress / ${mntpoint} || \
exit 1

#Remove the existing ${mntpoint}/etc/fstab file

rm -f ${mntpoint}/etc/fstab

#Update ${mntpoint}/etc/fstab file, so that we dont loose mountpoints after instance reboot
echo "/dev/mapper/vg_sys-lv_root / ext4 defaults 0 0" >> ${mntpoint}/etc/fstab
echo "/dev/mapper/vg_sys-lv_var /var ext4 rw,relatime,data=ordered   0 0" >> ${mntpoint}/etc/fstab
echo "/dev/mapper/vg_sys-lv_varlog /var/log ext4  rw,relatime,data=ordered   0 0" >> ${mntpoint}/etc/fstab
echo "/dev/mapper/vg_sys-lv_tmp /tmp ext4 rw,nosuid,nodev,relatime 0 0" >> ${mntpoint}/etc/fstab
echo "/dev/mapper/vg_sys-lv_home /home ext4 rw,nodev,relatime,data=ordered 0 0" >> ${mntpoint}/etc/fstab
echo "/dev/mapper/vg_sys-lv_varlogaudit /var/log/audit ext4  rw,relatime,data=ordered   0 0" >> ${mntpoint}/etc/fstab
echo "/dev/mapper/vg_sys-lv_vartmp /var/tmp ext4  rw,relatime,data=ordered   0 0" >> ${mntpoint}/etc/fstab
echo "/dev/vg_sys/lv_swap swap swap defaults 0 0" >> ${mntpoint}/etc/fstab
echo "tmpfs /dev/shm tmpfs  rw,nosuid,nodev,noexec 0 0" >> ${mntpoint}/etc/fstab
