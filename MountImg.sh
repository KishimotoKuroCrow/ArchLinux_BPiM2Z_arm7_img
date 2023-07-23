#!/bin/bash

IMGFILE=$1
CURRENTPATH=$(pwd)
MOUNTPATH=${CURRENTPATH}/ThisImgRoot

mkdir -p ${MOUNTPATH}/boot
losetup -fP ${IMGFILE}
DEVDISK=$(losetup --list | grep ${IMGFILE} | awk '{print $1}')

mount ${DEVDISK}p2 ${MOUNTPATH}
mount ${DEVDISK}p1 ${MOUNTPATH}/boot

cat > ./UMOUNT.sh <<EOL
#!/bin/bash
umount ${MOUNTPATH}/boot
umount ${MOUNTPATH}
losetup -d ${DEVDISK}
EOL
chmod +x ./UMOUNT.sh
