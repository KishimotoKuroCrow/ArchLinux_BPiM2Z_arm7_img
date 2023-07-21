#!/bin/bash

USERNAME=$1
WIFI_INTF=$2

# Setup directory
cd ~/
echo 'history -c' >> ~/.bash_logout
echo 'echo "" > ~/.bash_history' >> ~/.bash_logout


# disable this script
chmod -x ~/user_pref.sh


# Quit
exit
