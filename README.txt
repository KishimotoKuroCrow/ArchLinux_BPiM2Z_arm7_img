username: bpim2z
password: monkey

root password: bananazero

----------------------
1) Disk should be automatically filled. on the terminal, type

   cmdline> df -h

and you should see the "/" partition taking most of the space
of your card.

----------------------
2) XFCE4 desktop environment is installed, but you'll have to
start it manually.

   cmdline> startxfce4

----------------------
3) The following terminal text editors are installed
- nano
- vi/vim

----------------------
4) 
   cmdline> pacman -Syyu        # Update the system
   cmdline> pacman -Ss <pack>   # Search the name of the package containing "pack"
   cmdline> pacman -S package   # Install a package

----------------------
5) For wireless (very short range for BPI M2 Zero), use NETCTL
 --> /etc/netctl/wireless_profile
    - ESSID=your_wifi_network_name
    - Key=wifi_password_plaintext

 cmdline> sudo netctl restart wireless_profile  # restart network to reflect changes
