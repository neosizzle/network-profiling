#!/bin/bash

# NOTE: Affects of this change does not persist between reboots
# This is to facilitate RFS (map the packet processing task to the cpu that asksed for the packet), run this after every boot
# https://www.kernel.org/doc/Documentation/networking/scaling.txt

default_interface="wlp0s20f3"
read -p "Enter interface name seen in ifconfig (default: $default_interface): " interface
if ! [[ "$interface" =~ ^[0-9]+$ ]]; then
	interface=$default_interface
fi

# 32768 is recommended from Documentation/networking/scaling.txt
default_entries="32768"
read -p "Enter entries (default: $default_entries): " entries
if ! [[ "$entries" =~ ^[0-9]+$ ]]; then
	entries=$default_entries
fi

sudo sh -c "echo $entries > /proc/sys/net/core/rps_sock_flow_entries"
sudo sh -c "echo $entries > /sys/class/net/$interface/queues/rx-0/rps_flow_cnt"