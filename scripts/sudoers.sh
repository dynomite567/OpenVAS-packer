#!/bin/bash

apt-get -y install sudo

# Set up password-less sudo for user openvas
echo 'openvas ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/openvas
chmod 440 /etc/sudoers.d/openvas

# no tty
echo "Defaults !requiretty" >> /etc/sudoers
