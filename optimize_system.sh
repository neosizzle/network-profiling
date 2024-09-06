# Run this script every boot
# https://rigtorp.se/low-latency-guide/
# https://talawah.io/blog/extreme-http-performance-tuning-one-point-two-million
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/tuning-the-network-performance_monitoring-and-managing-system-status-and-performance

echo -n "Please enter adapter name: "
read adapter

# Increase NIC and driver ring buffer size to prevent drop rate
# ethtool -S $adapter
# ethtool -g $adapter # to verify
sudo ethtool -G $adapter rx 16384 # this value is AWS max size, we got 1024 by default

# When a network card receives packets and before the kernel protocol stack processes them, the kernel stores these packets in backlog queues. The kernel maintains a separate queue for each CPU core.
# If the backlog queue for a core is full, the kernel drops all further incoming packets that the netif_receive_skb() kernel function assigns to this queue. If the server contains a 10 Gbps or faster network adapter or multiple 1 Gbps adapters, tune the backlog queue size to avoid this problem.
# Only improvment on server ? 
sudo echo "net.core.netdev_max_backlog = 2000" > /etc/sysctl.d/10-netdev_max_backlog.conf
sudo sysctl -p /etc/sysctl.d/10-netdev_max_backlog.conf # default is 1000

# If irqbalance is not running, usually the CPU core 0 handles most of the interrupts, including network packet receives
# sudo systemctl enable --now irqbalance

# Increasing the time SoftIRQs can run on the CPU
awk '{for (i=1; i<=NF; i++) printf strtonum("0x" $i) (i==NF?"\n":" ")}' /proc/net/softnet_stat | column -t
echo If the counters in the third column of the /proc/net/softnet_stat file increment over time, tune the system

# C-State / consumption states tuning. The higher the state, the more power saving it wants to be.
cat /sys/module/processor/parameters/max_cstate
sudo grubby --update-kernel=ALL --args="intel_idle.max_cstate=0" # default is 8

# Hyper-threading (HT) or Simultaneous multithreading (SMT) is a technology to maximize processor resource usage for workloads with low instructions per cycle (IPC). Since HT/SMT increases contention on processor resources it’s recommended to turn it off if you want to reduce jitter introduced by contention on processor resources. Disabling HT / SMT has the additional benefit of doubling (in case of 2-way SMT) the effective L1 and L2 cache available to a thread.
# [EXPERIMENTAL]
sudo echo off > /sys/devices/system/cpu/smt/control

# Try to move all kernel threads and workqueues to core 0:
sudo pgrep -P 2 | sudo xargs -i taskset -p -c 0 {}
sudo find /sys/devices/virtual/workqueue -name cpumask  -exec sh -c 'echo 1 > {}' ';'

# disable swap to reduce pagefaults
sudo swapoff -a

# disable TLB, which makes kernel not promote normal pages into huge pages
# this promotion causus latency spike
# this is disabled by default already, so its OK
sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled

# Disable iptables, NAT has overhead
modprobe -rv ip_tables

# RSS

# XPS

# adaptive rx
sudo ethtool -C $adapter adaptive-rx on

# lower tx_usesecs
sudo ethtool -C $adapter tx-usecs 256

# disable DCHP - we dont have DHCP client :-)
# dhclient -x -pf /var/run/dhclient-eth0.pid
# dhclient -x -pf /var/run/dhclient6-eth0.pid
# ip addr change $( ip -4 addr show dev eth0 | grep 'inet' | awk '{ print $2 " brd " $4 " scope global"}') dev eth0 valid_lft forever preferred_lft forever

# disable syscall auditing
# sudo echo "-a never,task" > /etc/audit/rules.d/disable-syscall-auditing.rules
sudo sh -c "echo '-a never,task' > /etc/audit/rules.d/audit.rules"
sudo /sbin/augenrules --load

# Disable ssm agent. It doesn't really affect throughput, but any network activity can affect p99 and stdev for latency
sudo systemctl stop amazon-ssm-agent
sudo systemctl disable amazon-ssm-agent

# Configure sysctls
# vm.swappiness -> how aggro do we use swap memory
# vm.dirty_ratio ->  is the percentage of system memory which when dirty (changes are made in local memory, but have not write to disk), causes the process doing writes to block and write out dirty pages to the disk.

# TODO: network config?
# net.core.somaxconn=2048
# net.ipv4.tcp_max_syn_backlog=10000
# net.core.busy_poll=1
# net.core.default_qdisc=noqueue
# net.ipv4.tcp_congestion_control=reno
cat > /etc/sysctl.d/90-extreme.conf <<- EOF
vm.swappiness=0
vm.dirty_ratio=80
EOF

# Reload sysctl to pick up new configs
sudo sysctl -p