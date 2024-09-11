
#!/usr/bin/env bash

set -eu

# pname=2 # default to 'kthreadd'
# for pid in $(pgrep "${pname}"); do
#     for tid in $(taskset --all-tasks -p "${pid}" | awk '{print $2}' | sed 's/.\{2\}$//' ); do
#         thread_name=`cat /proc/${tid}/comm`;
# 		process_name=`ps -p $tid -o comm=`;
# 		echo -n "$process_name "
# 		taskset -cp $tid
#     done
# done

pname=${2:-systemd}  # default to 'systemd'
for pid in $(pgrep "${pname}"); do
    for tid in $(taskset --all-tasks -p "${pid}" | awk '{print $2}' | sed 's/.\{2\}$//' ); do
        thread_name=`cat /proc/${tid}/comm`;
		process_name=`ps -p $tid -o comm=`;
		echo -n "$process_name "
		taskset -cp $tid
    done
done
