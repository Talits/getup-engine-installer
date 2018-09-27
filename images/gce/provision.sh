#!/bin/bash

if [ -e /root/.provisioned ]; then
    echo "Instance already provisioned. Remove /root/.provisioned to force."
    exit 0
fi

set -ex

exec 2>&1
exec >>/var/log/provision.log

date

## Ansible need to sudo without tty
sed -i 's/Defaults\s\+requiretty/Defaults !requiretty/g' /etc/sudoers

## Install base packages
yum update -y
yum install -y NetworkManager nc docker

systemctl stop docker-storage-setup docker
# docker will be enabled during boot from setup-host.sh script
systemctl disable docker-storage-setup docker

easy_install pip
pip install -U pip

## Setup network interfaces
for ifcfg_eth in /etc/sysconfig/network-scripts/ifcfg-eth*; do
    if grep -q NM_CONTROLLED $ifcfg_eth; then
        sed 's/.*NM_CONTROLLED=.*/NM_CONTROLLED=yes/' -i $ifcfg_eth
    else
        echo 'NM_CONTROLLED=yes' >> $ifcfg_eth
    fi
    nmcli con load $ifcfg_eth
done

systemctl enable NetworkManager
#systemctl start NetworkManager

touch /root/.provisioned
