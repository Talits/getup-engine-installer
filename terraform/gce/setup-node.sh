#!/bin/bash

set -ex

exec 2>&1

date

# From OKD reference architecture
# https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_google_cloud_platform/#creating_google_cloud_platform_instances
LOCALVOLDEVICE=$(readlink -f /dev/disk/by-id/google-*local*)
CONTAINERSDEVICE=$(readlink -f /dev/disk/by-id/google-*containers*)
ETCDDEVICE=$(readlink -f /dev/disk/by-id/google-*etcd* || true)

LOCALDIR="/var/lib/origin/openshift.local.volumes"
CONTAINERSDIR="/var/lib/docker"
ETCDDIR="/var/lib/etcd"

for device in ${LOCALVOLDEVICE} ${CONTAINERSDEVICE} ${ETCDDEVICE}
do
  mkfs.xfs -f ${device}
done

for dir in ${LOCALDIR} ${CONTAINERSDIR} ${ETCDDEVICE:+$ETCDDIR}
do
  mkdir -p ${dir}
  restorecon -R ${dir}
done

echo UUID=$(blkid -s UUID -o value ${LOCALVOLDEVICE}) ${LOCALDIR} xfs defaults,discard,gquota 0 2 >> /etc/fstab
echo UUID=$(blkid -s UUID -o value ${CONTAINERSDEVICE}) ${CONTAINERSDIR} xfs defaults,discard 0 2 >> /etc/fstab

if [ -e "$ETCDDEVICE" ]; then
    echo UUID=$(blkid -s UUID -o value ${ETCDDEVICE}) ${ETCDDIR} xfs defaults,discard 0 2 >> /etc/fstab
fi

mount -a

exit 0

if [ ! -e /root/.provisioned ]; then
    echo "WARNING: Instance was not properly provisioned."
fi

systemctl stop docker-storage-setup docker

## Create emptyDir partition
VOLUMES_DEV=${VOLUMES_DEV:-/dev/sdb}
VOLUMES_DIR=${VOLUMES_DIR:-/var/lib/origin/openshift.local.volumes}

if ! grep -q ${VOLUMES_DEV} /etc/fstab; then
    mkdir -p ${VOLUMES_DIR}
    mkfs.xfs ${VOLUMES_DEV}
    grep ${VOLUMES_DEV} /etc/fstab || echo ${VOLUMES_DEV} ${VOLUMES_DIR} xfs defaults,grpquota 0 0 >> /etc/fstab
    mount ${VOLUMES_DEV}
fi

## Setup docker containers dir
CONTAINERS_DEV=${CONTAINERS_DEV:-/dev/sdc}
CONTAINERS_DIR=${CONTAINERS_DIR:-/var/lib/docker}

if ! grep -q ${CONTAINERS_DIR} /etc/fstab; then
    mkdir -p ${CONTAINERS_DIR}
    mkfs.xfs ${CONTAINERS_DEV}
    grep ${CONTAINERS_DEV} /etc/fstab || echo ${CONTAINERS_DEV} ${CONTAINERS_DIR} xfs defaults 0 0 >> /etc/fstab
else
    umount ${CONTAINERS_DEV} || true
    rm -rf $CONTAINERS_DIR
    mkdir -p $CONTAINERS_DIR
fi

mount ${CONTAINERS_DEV}

## Setup docker storage
LVM_DEV=${LVM_DEV:-/dev/sdd}
cat > /etc/sysconfig/docker-storage-setup <<EOF
DEVS='${LVM_DEV}'
VG=docker
DATA_SIZE=95%VG
STORAGE_DRIVER=devicemapper
WIPE_SIGNATURES=true
EOF

rm -f /etc/sysconfig/docker-storage
systemctl enable docker-storage-setup docker
systemctl start docker-storage-setup docker
