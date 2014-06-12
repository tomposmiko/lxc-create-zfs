#!/bin/bash

export PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LXC_BASE="/tank/lxc"

CONTAINER=$1




if ! IP=`host $CONTAINER | egrep -o "([0-9]{1,3}(\.[0-9]{1,3}){3})"`;then
	echo Error in DNS!
	exit 1
fi

GW=`ip ro sh |awk '/^default/ { print $3 }'`
NM=`ifconfig |grep -A1 br-| awk -F: '/Mask:/ { print $4 }'`

if ! debootstrap --help >/dev/null 2>&1; then
	echo "ERROR: No debootstrap";
	exit 1
fi



if [ -e $LXC_BASE/$CONTAINER ];then
	echo 'ERROR: Container exists!'
	exit 1
fi


# lxc
if ! lxc-create -n $CONTAINER -t ubuntu -- -r trusty; then
# -- -a i386
	echo "ERROR: lxc-create";
	exit 1
fi

cd $LXC_BASE

rm -rf ${CONTAINER}.tmp
mv $CONTAINER ${CONTAINER}.tmp
#zfs create `echo $LXC_BASE/$CONTAINER|sed 's@/data@tank@'`
if ! zfs create `echo $LXC_BASE/$CONTAINER|cut -f2- -d/`;then
	echo "ERROR: zfs create";
	exit 1
fi

mv ${CONTAINER}.tmp/* ${CONTAINER}/
rm -rf ${CONTAINER}.tmp



# apt
cp -f  /etc/apt/apt.conf.d/recommends $LXC_BASE/$CONTAINER/rootfs/etc/apt/apt.conf.d/


CMD="chroot $LXC_BASE/$CONTAINER/rootfs"

if ! $CMD /bin/echo;then
	echo "ERROR: chroot"
	exit 1
fi

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

cat >  $LXC_BASE/$CONTAINER/rootfs/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address $IP
	netmask $NM
	gateway $GW
EOF

lxc-start -d -n $CONTAINER
