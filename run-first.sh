#!/bin/bash
#
# Initializes a new LXD container
#

if [ "$container" != "lxc" ]
then
	echo "You probably want to run this script inside a container!"
	exit 1
fi

# fix resolvconf's broken postrm in xenial
RESOLVCONF="/etc/resolv.conf"
[ -L $RESOLVCONF ] && mv $RESOLVCONF{.host,}

# delete user 'ubuntu'
userdel -r ubuntu

# disable root password
sed -ie 's/^\(root:\)[^:]\+/\1!/g' /etc/shadow

# packages
apt-get update
apt-get install language-pack-en language-pack-hu puppet vim -y
DEBIAN_FRONTEND=noninteractive apt-get remove --purge resolvconf libnspr4 libdrm-intel1 libdrm-radeon1 -y --allow-remove-essential
locale-gen hu_HU

# remove the containers /etc/localtime so tzdata can reinitialize
# itself properly
rm /etc/localtime
