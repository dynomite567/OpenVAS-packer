#!/bin/bash

# Clean up
apt-get -y --purge remove linux-headers-$(uname -r) build-essential openssh-server
apt-get -y --purge autoremove
apt-get -y purge $(dpkg --list |grep '^rc' |awk '{print $2}')
apt-get -y purge $(dpkg --list |egrep 'linux-image-[0-9]' |awk '{print $3,$2}' |sort -nr |tail -n +2 |grep -v $(uname -r) |awk '{ print $2}')
apt-get -y clean

# Remove files
unset HISTFILE
rm ~/.bash_history /home/openvas/.bash_history
rm /home/openvas/openvas

# sync data to disk (fix packer)
sync
