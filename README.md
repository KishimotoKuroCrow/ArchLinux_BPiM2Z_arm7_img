# Script to generate an Arch Linux Arm image for BananaPi M2 Zero
## BananaPi M2 Zero board, Quick Specs
* Quad-core 1.296GHz, ARMv7 (Cortex-A7)
* 512MB DDR3 SDRAM
* WiFi (very short range unless antenna is connected)
* Bluetooth
* Micro USB for power
* Micro USB OTG
* Mini HDMI (provided converter doesn't work, use direct cable)
* More info: [BPi M2 Zero Wiki](https://wiki.banana-pi.org/Banana_Pi_BPI-M2_Zero)

## Table of Contents
* [Pre-Requisites](#prerequisites)
* [Setup](#setup)
* [Installation](#installation)
* [Quick Explanation](#explanation)
* [Encountered Problems](#problems)
* [References](#references)

<a name="prerequisites"></a>
## Pre-requisites (guide written in July 2023)
* Arch Linux HOST (my script uses arch-chroot)
* Install the following list of packages from official repository
```
$ sudo pacman -S parted \
                 wget \
                 arm-none-eabi-gcc \
                 arm-none-eabi-binutils \
                 qemu-user-static-binfmt \
                 qemu-user-static
```
* Restart systemd-binfmt.service
```
$ sudo systemctl restart systemd-binfmt.service
```

<a name="setup"></a>
## Setup
1) Change the hostname to the one you want in **_Img\_Setup\_Arch\_BPiM2Zero\_Armv7.sh_**
```
HOSTNAME=ALA_BPiM2Z
```
2) Change the personalization parameters in **_Machine\_Setup\_Arch.sh_**
```
USERNAME=bpim2z         # Username of the new account
PASSWORD=monkey         # Password of the new account
ROOTPWD=bananazero      # Root Password
SSHPORT=16500           # New SSH port instead of the default 22
ESSID_NAME=MyWifiName   # Wifi hotspot to connect to
WIFI_PWD=MyWifiPassword # Plain text Wifi password
```
3) Edit the list of packages you want to pre-installed in your setup
   in **_pkglist.txt_**

4) Personalize your configuration for root and local user in **_root\_pref.sh_** and **_user\_pref.sh_**
   respectively.

<a name="installation"></a>
## Installation
Run the following script. It'll generate a 4GB empty file, set it up as a loop device, and mount it
as a disk for partition and installation. Everything is detected automatically. 3.5GB would have been
enough.
```
$ sudo ./Img_Setup_ArchBPiM2Zero_Arm7.sh
```
At the end of a successful image creation called "alarm_sd.img". Connect your microSD card to the computer, 
find the device associated to your card, and burn the image to it.
```
$ sudo fdisk -l
$ sudo dd if=./alarm_sd.img of=/dev/sde bs=2M status=progress
```
Insert the card to the BananaPi M2 Zero board, boot it up and connect remotely using SSH or
directly from the board.
```
$ ssh -p 16500 bpim2z@<ip_addr>
```
Upon first boot, the system will resize the root partition to fill the rest of the card's available space.


<a name="explanation"></a>
## Quick Explanation
###### Img\_Setup\_ArchBPiM2Zero\_Arm7.sh
* Creates an empty image and link it to a loop device.
* Creates the necessary partitions.
* Download the latest Arch Linux ARMv7 image (if not already done).
* Create mount points, extract the image above, copy scripts, chroot for configuration, generate boot scripts.
* Create the U-Boot binary file (if not already done) and burn it.

###### Machine\_Setup\_Arch.sh
* Called by **_Img\_Setup\_ArchBPiM2Zero\_Arm7.sh_**
* Initialize the Arch Linux system.
* Set locale and localtime.
* Delete default user "alarm" and create a new user account.
* Setup networking and remote connection (SSH using key file, or by username/password).
* Setup first boot script for resizing root partition.
* Setup scripts for faster boot and reboot/shutdown scripts.

###### script.exp
* Called by first boot script.
* Find the device of the root partition, deletes it, and then recreate it with all the available space.
* Force kernel to update its partition disk.
* Resize the filesystem of the new root partition.

###### root\_pref.sh
* Called by **_Machine\_Setup\_Arch.sh_**
* Setup root preferences.

###### user\_pref.sh
* Called by **_Machine\_Setup\_Arch.sh_**
* Setup additional user preferences.

<a name="problems"></a>
## Encountered Problems
1) No HDMI display no matter what image I burn:
> The provided Mini HDMI to full HDMI converter did not work. I had to get a 
direct cable to get it to work.

2) When compiling on the board, it sometimes kicks me back to login screen:
> The board only has 512MB of memory, you'll need to create a swapfile.
When you're done, delete that swapfile because it's not good to keep it 
in a MicroSD card.
```   
# Create swapfile
$ sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
$ sudo chmod 0600 /swapfile
$ sudo mkswap -U clear /swapfile
$ sudo swapon /swapfile
$ sync

# Delete swapfile
$ sudo swapoff /swapfile
$ sudo rm -f /swapfile
```
3) I can't install and configure everything during arch-chroot:
> Not everything can be done during arch-chroot, you'll need to log into the board 
(physically or remotely) and run the commands. To make it easier, I recommend
generate the scripts while in arch-chroot so that once logged in, you can 
simply run the scripts in the designated folders or have them run on 
first boot.

<a name="references"></a>
## References
https://unix.stackexchange.com/questions/501626/create-bootable-sd-card-with-parted \
https://bbs.archlinux.org/viewtopic.php?id=204252 \
https://itsfoss.com/install-arch-raspberry-pi/ \
https://github.com/sosyco/bananapim2zero/blob/master/docs/installation_english.md
