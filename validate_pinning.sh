#!/bin/bash

# Function to print process info and recurse into children
print_process_info() {
    local pid=$1
    local indent=$2
    local is_thread=$3

    # Print the process/ thread name and its CPU affinity
    local proc_name
    proc_name=$(ps -p "$pid" -o comm=)
    if [[ "$is_thread" -eq 1 ]]; then
        proc_name=$(ps -eL | awk '{print $2, $5}' | grep -E "^ *$pid" | awk '{print $2}')
    fi
    local cpu_affinity
    cpu_affinity=$(taskset -pc "$pid" | awk '{print $NF}')
    local output="${indent}PID: $pid, Name: $proc_name, CPU Affinity: $cpu_affinity"
    if [[ "$is_thread" -eq 1 ]]; then
        output="${indent}TID: $pid, Name: $proc_name, CPU Affinity: $cpu_affinity"
    fi

    echo "${output}"

    # Recurse into threads
    local threads
    threads=$(ps -Lp "$pid" -o tid= |  tail -n +2)
    for child_pid in $threads; do
        print_process_info "$child_pid" "  $indent" 1
    done

    # Recurse into children process
    local child_pids
    child_pids=$(pgrep -P "$pid")

    for child_pid in $child_pids; do
        print_process_info "$child_pid" "  $indent" 0
    done
}

default_value=2
echo -n "Enter root pid (1 for userland, 2 for kernel - default): "
read root_pid

# Check if the input is a valid number
if ! [[ "$root_pid" =~ ^[0-9]+$ ]]; then
    root_pid=$default_value
else
    # Check if the input is within the range
    if (( root_pid < 1 || root_pid > 2 )); then
        root_pid=$default_value
    fi
fi


# Start with the root process or any process you want to start from
print_process_info "$root_pid" "" 0
