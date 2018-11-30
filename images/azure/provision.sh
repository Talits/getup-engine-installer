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
yum install -y NetworkManager nc git

easy_install pip
pip install --upgrade pip setuptools --force-reinstall
pip install --upgrade openshift --force-reinstall --ignore-installed ipaddress

systemctl enable NetworkManager
systemctl start NetworkManager

## Setup network interfaces
for ifcfg_eth in /etc/sysconfig/network-scripts/ifcfg-eth*; do
    if grep -q NM_CONTROLLED $ifcfg_eth; then
        sed 's/.*NM_CONTROLLED=.*/NM_CONTROLLED=yes/' -i $ifcfg_eth
    else
        echo 'NM_CONTROLLED=yes' >> $ifcfg_eth
    fi
    nmcli con load $ifcfg_eth
done


## TODO: up to this point we soulhd have an AMI to minimize provisioning time

## Create emptyDir partition
VOLUMES_DEV=${VOLUMES_DEV:-/dev/sdc}
VOLUMES_DIR=${VOLUMES_DIR:-/var/lib/origin/openshift.local.volumes}

if [ ! -d ${VOLUMES_DIR} ]; then
    mkdir -p ${VOLUMES_DIR}
    mkfs.xfs ${VOLUMES_DEV}
    grep ${VOLUMES_DEV} /etc/fstab || echo ${VOLUMES_DEV} ${VOLUMES_DIR} xfs defaults,grpquota 0 0 >> /etc/fstab
    #mount ${VOLUMES_DEV} || mount ${VOLUMES_DIR}
fi

yum install -y docker
systemctl stop docker-storage-setup
systemctl stop docker

sleep 1

rm -rf /var/lib/docker/
mkdir -p /var/lib/docker/

LVM_DEV=${LVM_DEV:-/dev/sdd}
cat > /etc/sysconfig/docker-storage-setup <<EOF
DEVS='${LVM_DEV}'
VG=docker
DATA_SIZE=95%VG
STORAGE_DRIVER=devicemapper
WIPE_SIGNATURES=true
EOF

systemctl enable docker-storage-setup
systemctl enable docker
#systemctl start docker-storage-setup
#systemctl start docker

echo $RELEASE > /root/.release
touch /root/.provisioned
