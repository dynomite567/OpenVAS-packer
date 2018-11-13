#!/bin/bash

apt update

apt-get -y install perl make linux-headers-$(uname -r) xserver-xorg

apt-get -y install open-vm-tools open-vm-tools-desktop

exit 0
