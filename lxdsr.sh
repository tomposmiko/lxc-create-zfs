#!/bin/bash

interactive=0
if /usr/bin/tty > /dev/null;
    then
        interactive=1
fi

# https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh
uncolorize () { sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"; }
if [ $interactive -eq 1 ]
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


export PATH="/root/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

dataset_list=`mktemp /tmp/datasets.XXXXXX`
zfs list -t snap -r -H tank -o name -s name tank/lxd/containers | grep @snapshot- | sed -e 's@tank/lxd/containers/@@' -e 's,@snapshot-,/,' > $dataset_list

for snap in "$@";do
	for dataset_path in `grep $snap $dataset_list`;do
		say "$green lxc delete ${dataset_path}"
		lxc delete ${dataset_path}
	done
done

#rm ${dataset_list}
