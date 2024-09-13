#!/bin/bash

# Function to print process info and recurse into children
force_pin() {
    local pid=$1
    local init_affif=$2
    local is_thread=$3

	sudo taskset -cp $init_affif $pid

    # Recurse into threads
    local threads
    threads=$(ps -Lp "$pid" -o tid= |  tail -n +2)
    for child_pid in $threads; do
        force_pin "$child_pid" "$init_affif" 1
    done

    # Recurse into children process
    local child_pids
    child_pids=$(pgrep -P "$pid")

    for child_pid in $child_pids; do
        force_pin "$child_pid" "$init_affif" 0
    done
}

init_affif=$(taskset -cp 1 | awk '{print $NF}')
# Start with the root process or any process you want to start from
force_pin "1" "$init_affif" 0
