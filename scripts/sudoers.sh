#!/bin/bash

apt-get -y install sudo

# Set up password-less sudo for user cyberpatrioths18
echo 'cyberpatrioths18 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/cyberpatrioths18
chmod 440 /etc/sudoers.d/cyberpatrioths18

# no tty
echo "Defaults !requiretty" >> /etc/sudoers
