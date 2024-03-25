#!/bin/bash

#===================
#===================
# PERSONALIZATION
#===================
# User Account
USERNAME=bpim2z
PASSWORD=monkey

# Root Password
ROOTPWD=bananazero

# SSH port
SSHPORT=16500

# Wifi Connection
ESSID_NAME=MyWifiName
WIFI_PWD=MyWifiPassword
#===================
#===================

HOSTNAME=$1
WIFI_INTF=wlan0
STARTSCR=/root/startup.sh
SHUTSCR=/root/shutdown.sh
FBOOTSCR=/root/firstboot.sh

# Initialize the pacman keys
pacman-key --init
pacman-key --populate archlinuxarm

# Update Arch Linux system
sed -i 's/#Color/Color/g' /etc/pacman.conf
pacman -Syyu --noconfirm
sync

# Skip kms hooks and regenerate the image.
# mkinitcpio breaks after 36.1, but cryptsetup requires higher version
sed -i 's/#default_options=""/default_options="--skiphooks kms"/g' /etc/mkinitcpio.d/linux-armv7.preset
pacman -Sy mkinitcpio --noconfirm

# Clear the pacman cache
yes | pacman -Scc
sync

# Set device hostname
echo $HOSTNAME > /etc/hostname

# Set locale
sed -i 's/#en_US/en_US/g' /etc/locale.gen
sed -i 's/#C\.UTF/C.UTF/g' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Set localtime
ln -sf /usr/share/zoneinfo/US/Central /etc/localtime
hwclock --systohc

# Setup the hosts file
cat > /etc/hosts <<EOL
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME} pi.hole

::1       ip6-localhost ip6-loopback
EOL
sync

# This is commented out because I ended up not able to login
## Do not clear TTY
#sed -i 's/TTYVTDisallocate=yes/TTYVTDisallocate=no/g' /etc/systemd/system/getty.target.wants/getty\@tty1.service

# Change Root Password
echo root:${ROOTPWD} | chpasswd

# Loop through each package to install and clear Pacman's cache
# to minimize the image
while IFS="" read -r package || [ -n "${package}" ]
do
   pacman -S --noconfirm --needed ${package}
   sync
   yes | pacman -Scc
   sync
done < /root/pkglist.txt

# Set wheel in sudoers (installed from pkglist)
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Setup Wireless Connection
cat > /etc/netctl/wireless_profile <<EOL
Description="Start Wireless Profile"
Interface=${WIFI_INTF}
Connection=wireless
Security=wpa
IP=dhcp
IP6=stateless
ESSID=${ESSID_NAME}
Key=${WIFI_PWD}
EOL

echo '#!/bin/bash' > $STARTSCR
echo 'rfkill block bluetooth; sleep 1' >> $STARTSCR
echo 'netctl start wireless_profile; sleep 5'>> $STARTSCR

echo '#!/bin/bash' > $SHUTSCR
echo 'netctl stop wireless_profile; sleep 5'>> $SHUTSCR

# Remove default user "alarm"
userdel -r alarm

# Add User
useradd -m -G wheel -s /bin/bash -p $(echo ${PASSWORD} | openssl passwd -1 -stdin) $USERNAME

# Create the SSH key and set the ports and permissions
ssh-keygen -A
mkdir -p /home/$USERNAME/.ssh
cat /etc/ssh/ssh_host_rsa_key.pub > /home/$USERNAME/.ssh/authorized_keys
cp /etc/ssh/ssh_host_rsa_key /boot
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/*
chown -R $USERNAME /home/$USERNAME/.ssh

sed -i "s/#Port 22/Port ${SSHPORT}/g" /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords/PermitEmptyPasswords/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/#X11Forwarding/X11Forwarding/g' /etc/ssh/sshd_config
echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config
echo 'systemctl start sshd.service; sleep 1' >> $STARTSCR
echo 'systemctl stop sshd.service; sleep 1' >> $SHUTSCR
echo 'systemctl disable firstboot.service; sleep 1' >> $SHUTSCR

# Create the first boot script
cat > $FBOOTSCR <<EOL
#!/bin/bash

DISK=\$(fdisk -l | grep "^Disk /dev" | awk -F ':' '{print \$1}' | sed 's/Disk \\/dev\\///g')
sleep 1
ROOTPART=\$(df -h | grep /dev | grep -E '/\$' | awk '{print \$1}')
sleep 1
P2UUID=\$(blkid \${ROOTPART} | awk '{print \$2}' | sed 's/[UUID=|"]//g')
sleep 1
P2PARTUUID=\$(blkid \${ROOTPART} | awk '{print \$5}' | sed 's/[PARTUUID=|"]//g')
sleep 1
echo "DISK: \$DISK, Root Partition: \$ROOTPART, Partition UUID: \$P2UUID, Partition PARTUUID: \$P2PARTUUID"


PART2Start=\$(parted /dev/\${DISK} unit s print free | grep primary | grep -v boot | awk '{print \$2}' | sed 's/s//g')
sleep 1
PART2SZ=\$(parted /dev/\${DISK} unit s print free | grep primary | grep -v boot | awk '{print \$4}' | sed 's/s//g')
sleep 1
FREESZ=\$(parted /dev/\${DISK} unit s print free | grep Free | grep -v -E '^[[:space:]]+2s' | awk '{print \$3}' | sed 's/s//g')
sleep 1
echo "Partition Start Sector: \$PART2Start"
echo "Partition Size: \$PART2SZ"
echo "Free Size: \$FREESZ"

if [ -z \$FREESZ ]; then
   echo "No more free space, no resize possible."
else
   NEWSZ=\$((\${PART2SZ}+\${FREESZ}))
   sleep 1
   NEWEND=\$((\${PART2Start}+\${NEWSZ}-1))
   sleep 1
   echo "New Size: \$NEWSZ, New End: \$NEWEND"

   #echo "Delete Partition to merge unallocated space: printf 'Yes\\nIgnore\\n' | parted --script /dev/\${DISK} rm 2"
   #printf 'Yes\\nIgnore\\n' | parted --script /dev/\${DISK} rm 2
   echo "Delete Partition to merge unallocated space: ./script.exp \${DISK}"
   /root/script.exp \${DISK}
   sleep 1
   #echo "Create a new Partition: parted --script /dev/\${DISK} mkpart primary ext4 \${PART2Start}s \${NEWEND}s"
   #parted --script /dev/\${DISK} mkpart primary ext4 \${PART2Start}s \${NEWEND}s
   echo "Create a new Partition: parted --script /dev/\${DISK} mkpart primary ext4 \${PART2Start}s 100%"
   parted --script /dev/\${DISK} mkpart primary ext4 \${PART2Start}s 100%
   sleep 3

   echo "Update Kernel for Partition Table Change: partprobe /dev/\${DISK}"
   partprobe /dev/\${DISK}
   sleep 5

   echo "Resize File System: resize2fs \${ROOTPART}"
   resize2fs \${ROOTPART}
   sleep 2
fi

# Show Info
blkid
parted /dev/\${DISK} unit s print free
fdisk -l /dev/\${DISK}
lsblk /dev/\${DISK}
df -h /dev/\${DISK}*

# disable this script
chmod -x $FBOOTSCR
chmod -x /root/script.exp
EOL

# Set startup and shutdown scripts as executable
chmod +x $FBOOTSCR
chmod +x $STARTSCR
chmod +x $SHUTSCR

# Enable a startup service
cat > /etc/systemd/system/startup.service <<EOL
[Unit]
Description="Startup Service"

[Service]
ExecStart=$STARTSCR

[Install]
WantedBy=multi-user.target
EOL
systemctl enable startup.service

# Enabled a first boot service
cat > /etc/systemd/system/firstboot.service <<EOL
[Unit]
Description="First Boot Service"
After=startup.service
Before=getty.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$FBOOTSCR

[Install]
WantedBy=multi-user.target
EOL
systemctl enable firstboot.service

# Enable a shutdown service
cat > /etc/systemd/system/shutdown.service <<EOL
[Unit]
Description="Shutdown Service"

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/true
ExecStop=$SHUTSCR

[Install]
WantedBy=multi-user.target
EOL
systemctl enable shutdown.service

#
# PERSONALIZE ROOT 
#=========================
cd /root/
./root_pref.sh $USERNAME

#
# PERSONALIZE New User
#=========================
#cp /root/user_pref.sh /home/$USERNAME/
#cp /root/script.exp /home/$USERNAME/
#chown $USERNAME:$USERNAME /home/$USERNAME/script.exp
mv /root/user_pref.sh /home/$USERNAME/
mv /root/README.txt /home/$USERNAME/
chown $USERNAME:$USERNAME /home/$USERNAME/user_pref.sh
chown $USERNAME:$USERNAME /home/$USERNAME/README.txt
cd /home/$USERNAME
su $USERNAME ./user_pref.sh $USERNAME ${WIFI_INTF}

# Quit
exit

