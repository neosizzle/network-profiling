#!/bin/bash

# pin process and recurse into children
# pin_aff_recursive() {
#     local pid=$1
#     local indent=$2
# 	local aff=$3

#     # Print the process name and its CPU affinity
#     local proc_name
#     proc_name=$(ps -p "$pid" -o comm=)
#     local cpu_affinity
#     cpu_affinity=$(taskset -pc "$pid" | awk '{print $NF}')
    
#     echo "${indent}PID: $pid, Name: $proc_name, CPU Affinity: $cpu_affinity"

#     # Recurse into children
#     local child_pids
#     child_pids=$(pgrep -P "$pid")

#     for child_pid in $child_pids; do
#         print_process_info "$child_pid" "  $indent"
#     done
# }

# change /etc/default/grub based on user input on number of cores allocated
amend_isolcpu_and_exit() {
	local desired_kernel_cores=$1
	local max_core=$((desired_kernel_cores - 1))
	local min_core=0
	local isolcpu_param="$min_core-$max_core"

	echo "Current isolcpu setting is incorrect, making changes.."

	# check if isolcpu option already exists
	if sudo grep -q "isolcpus" /etc/default/grub; then
		sudo sed -i "s/isolcpus=[0-9]*\(-[0-9]*\)\?/isolcpus=$isolcpu_param/g" /etc/default/grub
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

# read from user on how many cores to allocate for kernel
default_kernel_cores=2
read -p "Enter desired number of kernel cores (default: 2): " desired_kernel_cores

# read from user on how many cores to allocate for non-application userspace
default_user_cores=2
read -p "Enter desired number of user system cores (default: 2): " desired_user_cores

if ! [[ "$desired_kernel_cores" =~ ^[0-9]+$ ]]; then
	desired_kernel_cores=$default_kernel_cores
fi

if ! [[ "$desired_user_cores" =~ ^[0-9]+$ ]]; then
	desired_user_cores=$default_user_cores
fi

total_desired=$((desired_user_cores + desired_kernel_cores))
spare_cores=$(($num_cores - $total_desired))
# check if desired numbers are within range
if (( total_desired < 1 || total_desired >= $num_cores )); then
	echo "Range error, falling back to default.."
	desired_kernel_cores=$default_kernel_cores
	desired_user_cores=$default_user_cores
fi

echo "Desired kernel cores: $desired_kernel_cores"
echo "Desired user cores: $desired_user_cores"
echo "Spare cores: $spare_cores"

# check for isolcpu in boot parameters
# check isolcpu correctness
current_isolated_cpus=$(sudo cat /sys/devices/system/cpu/isolated)
if [[ "$desired_kernel_cores" -eq 1 ]]; then
	if [[ "$current_isolated_cpus" -eq 0 ]]; then
		echo "isolcpu settings OK"
	else
		amend_isolcpu_and_exit 1
	fi
else
	segments=$(echo "$current_isolated_cpus" | awk -F'-' '{print NF}')
	if [[ "$segments" -ne 2 ]]; then
		amend_isolcpu_and_exit $desired_kernel_cores
	else
		min_core=$(echo "$current_isolated_cpus" | awk -F'-' '{print 0}')
		max_core=$(echo "$current_isolated_cpus" | awk -F'-' '{print 1}')
		# min core isolation should start with 0
		if [[ "$min_core" -ne 0 ]]; then
			amend_isolcpu_and_exit $desired_kernel_cores
		else
			# max core isolation should be be start of user cores TODO make space 4 spare
			if [[ "$max_core" -ne $(($desired_kernel_cores - 1)) ]]; then
				amend_isolcpu_and_exit $desired_kernel_cores
			fi
		fi
	fi
fi

echo "isolcpu OK"

# pin all kernel threads to core 0-desired_kernel_cores - 1
max_kernel_core_id=$(($desired_kernel_cores - 1))
kernel_aff="0-$max_kernel_core_id"
echo $kernel_aff