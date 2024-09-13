#!/bin/bash

# change /etc/default/grub based on user input on number of cores allocated
amend_isolcpu_and_exit() {
	local desired_isolcpus_mask=$1

	local isolcpu_param="$desired_isolcpus_mask"

	echo "Current isolcpu setting is incorrect, making changes.."

	# check if isolcpu option already exists
	if sudo grep -q "isolcpus" /etc/default/grub; then
		# sudo sed "s/isolcpus=[0-9]*\(-[0-9]*\)\?/isolcpus=$isolcpu_param/g" /etc/default/grub
		sudo sed -i "s/isolcpus=[0-9]*\(-[0-9]*\)\?\(\,[0-9]*\(-[0-9]*\)\?\)*\?/isolcpus=$isolcpu_param/g" /etc/default/grub
	else
	 	sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"\(.*\)\"/\"\1 isolcpus=$isolcpu_param\"/" /etc/default/grub
	fi
	echo "Changes are made, please update grub and reboot"
	exit
}

# calculate number of cores in system
get_num_cores() {
	lscpu | grep "CPU(s): " | head -n 1 | awk '{print $2}'
}

num_cores=$(get_num_cores)

echo "You have $num_cores cores in your system"

# read from user on new isolcpus mask
max_core_id=$((num_cores - 1))
default_isolcpus_mask="0-3,8-$max_core_id"
read -p "Enter desired isolcpus mask (default: $default_isolcpus_mask): " desired_isolcpus_mask
if [ -z "$desired_isolcpus_mask" ]; then
	desired_isolcpus_mask=$default_isolcpus_mask
fi

# check for isolcpu in boot parameters
# check isolcpu correctness
current_isolated_cpus=$(sudo cat /sys/devices/system/cpu/isolated)

if [[ "$desired_isolcpus_mask" != "$current_isolated_cpus" ]]; then
			amend_isolcpu_and_exit $desired_isolcpus_mask
fi


echo "isolcpu OK"