# This is to facilitate RSS, run this after every boot
# https://www.kernel.org/doc/Documentation/networking/scaling.txt

# calculate number of cores in system
get_num_cores() {
	lscpu | grep "CPU(s): " | head -n 1 | awk '{print $2}'
}

num_cores=$(get_num_cores)
echo "You have $num_cores cores in your system"

default_interface="iwlwifi"
read -p "Enter interface name seen in /proc/interrupts (default: $default_interface): " interface

if ! [[ "$interface" =~ ^[0-9]+$ ]]; then
	interface=$default_interface
fi

interript_entries=$(cat /proc/interrupts | grep $interface)
irq_nums=()
ifnames=()
new_affs=()

while IFS= read -r line; do
	irqnum=$(echo $line | awk '{print $1}' | sed 's/.$//')
	curr_if=$(echo $line | awk '{print $NF}')
	irq_nums+=($irqnum)
	ifnames+=($curr_if)
done <<< "$interript_entries"

for i in "${!ifnames[@]}"; do
	curr_irqnum=${irq_nums[i]}
	read -p "Enter CPU_NUMBER for ${ifnames[i]}: " new_affinity
	sudo sh -c "echo $new_affinity > /proc/irq/${irq_nums[i]}/smp_affinity_list"
done

echo "OK"