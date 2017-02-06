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

which lxc >/dev/null
if [ $? -ne 0 ]
then
    say "$red LXD not installed!"
    exit 1
fi

if ! IP=`host $CONTAINER | egrep -o "([0-9]{1,3}(\.[0-9]{1,3}){3})"`;then
    say "$red Error in DNS!"
    exit 1
fi

GW=`ip ro sh |awk '/^default/ { print $3 }'`
NM=`ifconfig |grep -A1 br-| awk -F: '/Mask:/ { print $4 }'`

#if ! debootstrap --help >/dev/null 2>&1; then
#    say "$red ERROR: No debootstrap";
#    exit 1
#fi

lxc info $CONTAINER >/dev/null 2>&1
if [ $? -eq 0 ]
then
    say "$red ERROR: Container exists!"
    exit 1
fi

lxc config show | grep "storage.zfs_pool_name: tank/lxd"
if [ $? -ne 0 ]
then
    say "$red ERROR: Container is not on ZFS pool!"
    exit 1
fi

# lxd
if ! lxc init images:centos/7/amd64 $CONTAINER ; then
# -- -a i386
    say "$red ERROR: lxd init";
    exit 1
fi

# push host's resolver to container
lxc file push /etc/resolv.conf $CONTAINER//etc/resolv.conf

# net
cat <<EOF | lxc file push - $CONTAINER//etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
NM_CONTROLLED=no
IPADDR=$IP
NETMASK=$NM
GATEWAY=$GW
EOF

#hostname
fqdn=$(host $CONTAINER | cut -d' ' -f1)
echo $fqdn | lxc file push - $CONTAINER//etc/hostname
echo $fqdn | lxc file push - $CONTAINER//etc/hostname2

cat <<'EOF' | lxc file push - $CONTAINER//run-first.sh
#!/bin/bash
#
# Initializes a new LXD container
#

if [ "$container" != "lxc" ]
then
	echo "You probably want to run this script inside a container!"
	exit 1
fi

echo " Starting runme :::"
# disable root password
sed -ie 's/^\(root:\)[^:]\+/\1!/g' /etc/shadow

# remove the containers /etc/localtime so tzdata can reinitialize
# itself properly
rm /etc/localtime
ln -s ../usr/share/zoneinfo/Europe/Budapest /etc/localtime
echo "Europe/Budapest" >/etc/timezone

#wait for network interface
echo ""
for i in {5..1}; do echo -n $i; sleep 1; done
echo ""

#install epel repo
rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

#install some base stuff (only puppet for now)
rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm

echo " Finished runme :::"
EOF

# push init script to container for execution
#lxc file push --mode=755 run-first-centos.sh $CONTAINER//run-first.sh

lxc start $CONTAINER

lxc exec $CONTAINER -- /bin/bash /run-first.sh

printf "\nPress ENTER to continue with Puppet... "
read answer

#enable puppet and generate cert
lxc exec $CONTAINER -- puppet agent --enable
lxc exec $CONTAINER -- puppet agent -t >/dev/null

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
