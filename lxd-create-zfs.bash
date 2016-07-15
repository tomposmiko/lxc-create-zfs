#!/bin/bash

# https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh

if [[ $- != *i* ]]
   then say() { echo -ne $1;echo -e $nocolor; }
        # Colors, yo!
        green="\e[1;32m"
        red="\e[1;31m"
        blue="\e[1;34m"
        purple="\e[1;35m"
        cyan="\e[1;36m"
        nocolor="\e[0m"
   else
        # do nothing
        say() { true; }
fi

export PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LXD_BASE="/var/lib/lxd/containers/"

CONTAINER=$1

if ! IP=`host $CONTAINER | egrep -o "([0-9]{1,3}(\.[0-9]{1,3}){3})"`;then
    say "$red Error in DNS!"
    exit 1
fi

GW=`ip ro sh |awk '/^default/ { print $3 }'`
NM=`ifconfig |grep -A1 br-| awk -F: '/Mask:/ { print $4 }'`

if ! debootstrap --help >/dev/null 2>&1; then
    say "$red ERROR: No debootstrap";
    exit 1
fi

if [ -e $LXD_BASE/$CONTAINER ];then
    say "$red ERROR: Container exists!"
    exit 1
fi

# lxd
if ! lxc launch official:ubuntu/xenial/amd64 $CONTAINER ; then
# -- -a i386
    say "$red ERROR: lxd launch";
    exit 1
fi

# stop container
lxc stop $CONTAINER

# apt
lxc file push /etc/apt/apt.conf.d/recommends $CONTAINER//etc/apt/apt.conf.d/

# net
cat <<EOF | lxc file push - $CONTAINER//etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address $IP
	netmask $NM
	gateway $GW
EOF

# push init script to container for execution
lxc file push --mode=755 run-first.sh $CONTAINER//run-first.sh

lxc start $CONTAINER

lxc exec $CONTAINER -- /run-first.sh
lxc exec $CONTAINER -- puppet agent -t --enable

printf "\nPress ENTER to continue with Puppet... "
read answer

while true; do
    echo -e "\nHave the puppet request been signed on the server?\n"
    read answer
    if [ "$answer" == yes ];
    then
        lxc exec $CONTAINER -- puppet agent -t
        lxc exec $CONTAINER -- puppet agent -t
        lxc exec $CONTAINER -- puppet agent -t
        exit 0
    fi
done
