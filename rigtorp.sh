# https://rigtorp.se/low-latency-guide/

# Hyper-threading (HT) or Simultaneous multithreading (SMT) is a technology to maximize processor resource usage for workloads with low instructions per cycle (IPC). Since HT/SMT increases contention on processor resources it’s recommended to turn it off if you want to reduce jitter introduced by contention on processor resources. Disabling HT / SMT has the additional benefit of doubling (in case of 2-way SMT) the effective L1 and L2 cache available to a thread.
# [EXPERIMENTAL]
sudo echo off > /sys/devices/system/cpu/smt/control

# To verify that SMT / HT is disabled the output of the following command should be 0:
# cat /sys/devices/system/cpu/smt/active

# Turbo boost and governor ommited due to lack of hardware support on prod

# TODO check if can overclock prod processors (no xeon)

# [TWEAK NEEDED]
# nohz_full - disable timers on core
# rch_nocb - disable rcu callbacks (for queuing lock operations) on core
# isolcpu - isolate cores from kernel scheduler [REBOOT NEEDED]
# mitigations - disable CPU security mitigations
# use cat /proc/cmdline to verify
echo -n "Please enter maximum CPU ID: "
read max_id
sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"\(.*\)"/"\1 isolcpus=1-$max_id nohz_full=1-$max_id rcu_nocbs=1-$max_id mitigations=off"/' /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Try to move all kernel threads and workqueues to core 0:
sudo pgrep -P 2 | sudo xargs -i taskset -p -c 0 {}
sudo find /sys/devices/virtual/workqueue -name cpumask  -exec sh -c 'echo 1 > {}' ';'

# disable swap to reduce pagefaults
sudo swapoff -a

# disable TLB, which makes kernel not promote normal pages into huge pages
# this promotion causus latency spike
# this is disabled by default already, so its OK
# sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled

# disable KSM, which is only enabled when madvise(..MADV_MERGEABLE) is used
# ommitied, this is not enabled in prod kernel
# sudo echo 0 > /sys/kernel/mm/ksm/run

echo "Please reboot instance to apply kernel parameters"