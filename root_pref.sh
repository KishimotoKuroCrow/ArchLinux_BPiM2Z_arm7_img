#!/bin/bash

USERNAME=$1

# Setup root directory
cd ~/
cp /etc/skel/.bash* ~/
echo 'history -c' >> ~/.bash_logout
echo 'echo "" > /root/.bash_history' >> ~/.bash_logout

# Disable this script
chmod -x /root/root_pref.sh

# Quit
exit
