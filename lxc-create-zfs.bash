#!/bin/bash

LXC_BASE="/data/lxc"

CONTAINER=$1

if [ -e $LXC_BASE/$CONTAINER ];then
    echo 'Container exists!!!'
    exit 1
fi


# lxc
lxc-create -n $CONTAINER -t ubuntu -- -r precise
# -- -a i386
sed -i s@/var/lib@/data@ /data/lxc/$CONTAINER/config || exit 1

cd $LXC_BASE

rm -rf ${CONTAINER}.tmp
mv $CONTAINER ${CONTAINER}.tmp
zfs create `echo $LXC_BASE/$CONTAINER|sed 's@/data@tank@'`

mv ${CONTAINER}.tmp/* ${CONTAINER}/
rm -rf ${CONTAINER}.tmp



# apt
cp -f  /etc/apt/apt.conf.d/recommends $LXC_BASE/$CONTAINER/rootfs/etc/apt/apt.conf.d/


CMD="chroot $LXC_BASE/$CONTAINER/rootfs"

# default user
$CMD userdel -r ubuntu

# apt
#cat > rootfs/etc/apt/apt.conf.d/recommends << EOF
#APT::Install-Recommends "0";
#APT::Install-Suggests "0";
#
#EOF


# packages

$CMD apt-get update
$CMD apt-get install language-pack-en language-pack-hu puppet vim -y
$CMD /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get remove --purge resolvconf -y --force-yes"
$CMD locale-gen hu_HU

$CMD sed -i "s@START=no@START=yes@" /etc/default/puppet

# passwd
echo root:a| $CMD chpasswd


# net

IP=`host $CONTAINER|sed "s/.*has address //"`

cat >  $LXC_BASE/$CONTAINER/rootfs/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $IP
    netmask 255.255.254.0
    gateway 10.0.1.254
EOF

lxc-start -d -n $CONTAINER
