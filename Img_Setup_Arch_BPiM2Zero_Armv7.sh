#!/bin/bash

# References:
#-------------
#https://unix.stackexchange.com/questions/501626/create-bootable-sd-card-with-parted 
#https://bbs.archlinux.org/viewtopic.php?id=204252
#https://itsfoss.com/install-arch-raspberry-pi/
#https://github.com/sosyco/bananapim2zero/blob/master/docs/installation_english.md

HOSTNAME=ALA_BPiM2Z
CURRENTDIR=$(pwd)
ARCHARMIMG=ArchLinuxARM-armv7-latest
IMGFILE=alarm_sd.img

# Make an empty 4GB image, set the loop device for the image
# (3.5GB would be more than enough for the image)
dd if=/dev/zero of=${CURRENTDIR}/${IMGFILE} bs=1M count=4096 status=progress
losetup -fP ${CURRENTDIR}/${IMGFILE}
DISK=$(losetup --list | grep ${IMGFILE} | awk '{print $1}' | sed 's/\/dev\///')

# Partition the SD card with input as the disk designation
# 1st partition: /boot: 256MB (200MB should be more than enough)
# 2nd partition: / : remaining
MOUNTROOT=/mnt/BPM2Z_Root
MOUNTBOOT=$MOUNTROOT/boot
FSTABFILE=$MOUNTROOT/etc/fstab
parted --script /dev/$DISK \
   mklabel msdos \
   mkpart primary ext4 1MiB 256MiB \
   mkpart primary ext4 256MiB 100% \
   set 1 boot on 
mkfs.ext4 /dev/${DISK}p1 -O ^has_journal,extent
mkfs.ext4 /dev/${DISK}p2 -O ^has_journal,extent

# Mount the paritions
mkdir -p $MOUNTROOT
mount /dev/${DISK}p2 $MOUNTROOT
mkdir -p $MOUNTBOOT
mount /dev/${DISK}p1 $MOUNTBOOT

# Check if the Arch Linux image is already present.
# If not, download it.
if [ ! -f "${ARCHARMIMG}.tar.gz" ]; then
   wget http://os.archlinuxarm.org/os/${ARCHARMIMG}.tar.gz
fi
bsdtar -xpf ${ARCHARMIMG}.tar.gz -C $MOUNTROOT
sync

# Generate the fstab and use the proper UUID
genfstab -p $MOUNTROOT >> $FSTABFILE
sync
UUID1=$(blkid /dev/${DISK}p2 | awk '{print $2}' | sed 's/"//g')
sed -i "s/\/dev\/${DISK}p2/${UUID1}/" ${FSTABFILE}
UUID2=$(blkid /dev/${DISK}p1 | awk '{print $2}' | sed 's/"//g')
sed -i "s/\/dev\/${DISK}p1/${UUID2}/" ${FSTABFILE}
sed -i 's/^\/\/.*//' ${FSTABFILE}
sed -i 's/.*swap.*//' ${FSTABFILE} 
sed -i "s/rw,relatime/defaults,noatime/g" ${FSTABFILE}
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,size=1G 0 0" | tee -a ${FSTABFILE}
echo "#tmpfs /var/log tmpfs rw,nodev,nosuid,size=32M 0 0" | tee -a ${FSTABFILE}
cat ${FSTABFILE}

# - pkglist: list of packages to install
# - userscript: execute script as a new user
chmod 666 ./pkglist.txt
chmod 777 ./user_pref.sh
chmod 777 ./script.exp
cp ./pkglist.txt $MOUNTROOT/root
cp ./user_pref.sh $MOUNTROOT/root
cp ./script.exp $MOUNTROOT/root
cp ./README.txt $MOUNTROOT/root
sync

# Change Environment Root and run Machine Setup script script
chmod 700 ./Machine_Setup_Arch.sh
chmod 700 ./root_pref.sh
cp ./Machine_Setup_Arch.sh $MOUNTROOT
cp ./root_pref.sh $MOUNTROOT/root
sync
arch-chroot $MOUNTROOT ./Machine_Setup_Arch.sh $HOSTNAME

# Get the Part UUID for rootfs and create the boot.cmd and boot.scr
BOOTFILEPATH=$MOUNTBOOT/boot
TARGET_PARTUUID=$(blkid /dev/${DISK}p2 | awk '{print $5}' | sed 's/"//g')
cat > ${BOOTFILEPATH}.cmd.bpim2z <<EOL
part uuid \${devtype} \${devnum}:\${bootpart} uuid
setenv bootargs console=tty1 console=serial0,115200 console=\${console} root=${TARGET_PARTUUID} rw rootwait audit=0 brcmfmac.feature_disable=0x82000

if load \${devtype} \${devnum}:\${bootpart} \${kernel_addr_r} zImage; then
  if load \${devtype} \${devnum}:\${bootpart} \${fdt_addr_r} dtbs/\${fdtfile}; then
    if load \${devtype} \${devnum}:\${bootpart} \${ramdisk_addr_r} initramfs-linux.img; then
      bootz \${kernel_addr_r} \${ramdisk_addr_r}:\${filesize} \${fdt_addr_r};
    else
      bootz \${kernel_addr_r} - \${fdt_addr_r};
    fi;
  fi;
fi

if load \${devtype} \${devnum}:\${bootpart} 0x48000000 uImage; then
  if load \${devtype} \${devnum}:\${bootpart} 0x43000000 script.bin; then
    setenv bootm_boot_mode sec;
    bootm 0x48000000;
  fi;
fi
EOL
sync

# Create boot.scr
cat > $MOUNTBOOT/bootgen.sh <<EOL
#!/bin/bash
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "BPi-M2 Zero Boot Script" -d boot.cmd.bpim2z boot.scr
EOL
sync
chmod +x $MOUNTBOOT/bootgen.sh 
sync
cd $MOUNTBOOT
./bootgen.sh

# Copy the SSH key file secure connection to the SHARE directory.
cd $CURRENTDIR
if [ -f $MOUNTROOT/etc/ssh/ssh_host_rsa_key ]; then
   cp $MOUNTROOT/etc/ssh/ssh_host_rsa_key ${MOUNTROOT}/${HOSTNAME}_key_4ssh
fi

# Generate the BIN file, copy it, and burn it.
BINFILE=u-boot-sunxi-with-spl.bin
if [ ! -f ${BINFILE} ]; then
   # Install compile and install U-Boot
   git clone git://git.denx.de/u-boot.git
   cd u-boot
   make -j4 ARCH=arm CROSS_COMPILE=arm-none-eabi- bananapi_m2_zero_defconfig
   make -j4 ARCH=arm CROSS_COMPILE=arm-none-eabi-
   sync
   cp ${BINFILE} ./../
   cd ../
fi
sync
dd if=${BINFILE} of=/dev/${DISK} bs=1024 seek=8
sync
losetup -d /dev/${DISK}

# Unmount the partitions and disconnect the image to loop device
umount $MOUNTBOOT
umount $MOUNTROOT
