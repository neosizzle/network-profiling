get_num_cores() {
	lscpu | grep "CPU(s): " | head -n 1 | awk '{print $2}'
}

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

num_cores=$(get_num_cores)
max_core_id=$(($num_cores - 1))
all_kthreads=$(print_process_info "2" "" 0)

total_threads=$(echo "$all_kthreads" | wc -l)
echo "Total Kthreads : $total_threads"
for i in $(seq 0 $max_core_id);
do 
	pinned_threads=$(echo "$all_kthreads" | grep "y: $i$" | wc -l)
	echo "Kthreads pinned to core $i: $pinned_threads"
done

# print_process_info "2" "" 0  |  grep "y: 11$" | wc -l