#!/bin/bash

# pin process and recurse into children
pin_aff_recursive() {
    local pid=$1
    local indent=$2
    local is_thread=$3
	local aff_to_pin=$4

    # Print the process/ thread name and its CPU affinity
    local proc_name
    proc_name=$(ps -p "$pid" -o comm=)
    if [[ "$is_thread" -eq 1 ]]; then
        proc_name=$(ps -eL | awk '{print $2, $5}' | grep -E "^ *$pid" | awk '{print $2}')
    fi
    local orig_cpu_affinity
    orig_cpu_affinity=$(taskset -pc "$pid" | awk '{print $NF}')
	new_affinity=$(sudo taskset -pc $aff_to_pin "$pid")

    local output="${indent}PID: $pid, Name: $proc_name, CPU Affinity: $cpu_affinity"
    if [[ "$is_thread" -eq 1 ]]; then
        output="${indent}TID: $pid, Name: $proc_name, CPU Affinity: $cpu_affinity"
    fi

    echo "${new_affinity}"

    # Recurse into threads
    local threads
    threads=$(ps -Lp "$pid" -o tid= |  tail -n +2)
    for child_pid in $threads; do
        print_process_info "$child_pid" "  $indent" 1 "$aff_to_pin"
    done

    # Recurse into children process
    local child_pids
    child_pids=$(pgrep -P "$pid")

    for child_pid in $child_pids; do
        pin_aff_recursive "$child_pid" "  $indent" 0 "$aff_to_pin"
    done
}

# change /etc/default/grub based on user input on number of cores allocated
amend_isolcpu_and_exit() {
	local desired_hotpath_cores=$1
	local desired_user_cores=$2
	local num_cores=$3

	local max_core_hotpath=$((desired_hotpath_cores - 1))
	local min_core_hotpath=0

	local max_core_user=$((num_cores - 1))
	local min_core_user=$((desired_hotpath_cores + $desired_user_cores))

	local isolcpu_param="$min_core_hotpath-$max_core_hotpath,$min_core_user-$max_core_user"

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

# read from user on how many cores to allocate for hotpath
default_hotpath_cores=4
read -p "Enter desired number of hotpath cores (default: $default_hotpath_cores): " desired_hotpath_cores

# read from user on how many cores to allocate for non-application userspace
default_user_cores=4
read -p "Enter desired number of user system cores (default: $default_user_cores): " desired_user_cores

if ! [[ "$desired_hotpath_cores" =~ ^[0-9]+$ ]]; then
	desired_hotpath_cores=$default_hotpath_cores
fi

if ! [[ "$desired_user_cores" =~ ^[0-9]+$ ]]; then
	desired_user_cores=$default_user_cores
fi

total_desired=$((desired_user_cores + desired_hotpath_cores))
spare_cores=$(($num_cores - $total_desired))
# check if desired numbers are within range
if (( total_desired < 1 || total_desired >= $num_cores )); then
	echo "Range error, falling back to default.."
	desired_hotpath_cores=$default_hotpath_cores
	desired_user_cores=$default_user_cores
fi

echo "Desired hotpath cores: $desired_hotpath_cores"
echo "Desired user cores: $desired_user_cores"
echo "Spare cores: $spare_cores"

# check for isolcpu in boot parameters
# check isolcpu correctness
current_isolated_cpus=$(sudo cat /sys/devices/system/cpu/isolated)
if [[ "$desired_hotpath_cores" -eq 1 ]]; then
	if [[ "$current_isolated_cpus" -eq 0 ]]; then
		echo "isolcpu settings OK"
	else
		amend_isolcpu_and_exit 1 $desired_user_cores $num_cores
	fi
else
	segments=$(echo "$current_isolated_cpus" | awk -F',' '{print NF}')
	if [[ "$segments" -ne 2 ]]; then
		amend_isolcpu_and_exit $desired_hotpath_cores $desired_user_cores $num_cores
	else
		first_segment=$(echo "$current_isolated_cpus" | awk -F',' '{print $1}')
		snd_segment=$(echo "$current_isolated_cpus" | awk -F',' '{print $2}')

		# check hotpath cores are correctly allocated
		first_subsegment=$(echo "$first_segment" | awk -F'-' '{print NF}')
		if [[ "$first_subsegment" -ne 2 ]]; then
			amend_isolcpu_and_exit $desired_hotpath_cores $desired_user_cores $num_cores
		else
			min_core=$(echo "$first_segment" | awk -F'-' '{print $1}')
			max_core=$(echo "$first_segment" | awk -F'-' '{print $2}')
			# min core hotpath should be 0
			if [[ "$min_core" -ne 0 ]]; then
				amend_isolcpu_and_exit $desired_hotpath_cores $desired_user_cores $num_cores
			else
				# max core hotpath should be be start of user cores 
				if [[ "$max_core" -ne $(($desired_hotpath_cores - 1)) ]]; then
					amend_isolcpu_and_exit $desired_hotpath_cores $desired_user_cores $num_cores
				fi	
			fi
		fi

		# check spare cores are correctly allocated
		snd_subsegment=$(echo "$snd_segment" | awk -F'-' '{print NF}')
		if [[ "$snd_subsegment" -ne 2 ]]; then
			amend_isolcpu_and_exit $desired_hotpath_cores $desired_user_cores $num_cores
		else
			min_core=$(echo "$snd_segment" | awk -F'-' '{print $1}')
			max_core=$(echo "$snd_segment" | awk -F'-' '{print $2}')
			min_spare=$total_desired
			# min core spare desired hotpath + desired user 
			if [[ "$min_core" -ne $min_spare ]]; then
				amend_isolcpu_and_exit $desired_hotpath_cores $desired_user_cores $num_cores
			else
				# max core spare should be num core - 1
				if [[ "$max_core" -ne $(($num_cores - 1)) ]]; then
					amend_isolcpu_and_exit $desired_hotpath_cores $desired_user_cores $num_cores
				fi	
			fi
		fi
	fi
fi

echo "isolcpu OK"

# pin all hotpath threads to core 0-desired_hotpath_cores - 1
max_hotpath_core_id=$(($desired_hotpath_cores - 1))
hotpath_aff="0-$max_hotpath_core_id"
# NOTE: KERNEL THREAD CANT BE PINNED DUE TO PF_NO_SETAFFINITY -> https://stackoverflow.com/questions/25359565/how-one-can-set-affinity-for-kernel-threads
# cat /proc/interrupts 
# pin_aff_recursive 2 "" 0 $hotpath_aff
echo "hotpath affinity is $hotpath_aff"