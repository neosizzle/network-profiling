# https://rigtorp.se/low-latency-guide/

# Hyper-threading (HT) or Simultaneous multithreading (SMT) is a technology to maximize processor resource usage for workloads with low instructions per cycle (IPC). Since HT/SMT increases contention on processor resources it’s recommended to turn it off if you want to reduce jitter introduced by contention on processor resources. Disabling HT / SMT has the additional benefit of doubling (in case of 2-way SMT) the effective L1 and L2 cache available to a thread.
# [EXPERIMENTAL]
sudo echo off > /sys/devices/system/cpu/smt/control

# To verify that SMT / HT is disabled the output of the following command should be 0:
cat /sys/devices/system/cpu/smt/active

# Turbo boost and governor ommited due to lack of hardware support on prod

# TODO check if can overclock prod processors (no xeon)

# isolcpu - isolate cores from kernel scheduler [REBOOT NEEDED]
# use cat /proc/cmdline to verify
sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"\(.*\)"/"\1 isolcpus=1-7"/' /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

