# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/tuning-the-network-performance_monitoring-and-managing-system-status-and-performance
# to check packet loss rate, run netstat -s | grep segments 
adapter=wlp0s20f3

# Increase NIC and driver ring buffer size to prevent drop rate
ethtool -S $adapter
ethtool -g $adapter
sudo ethtool -G ens5 rx 16384 # this value is AWS max size, we got 1024 by default

# these commands are unavail because amazon linux does not have networkanager in their mirrors
# nmcli connection show
# nmcli connection modify Example-Connection ethtool.ring-rx 4096
# nmcli connection modify Example-Connection ethtool.ring-tx 4096

# When a network card receives packets and before the kernel protocol stack processes them, the kernel stores these packets in backlog queues. The kernel maintains a separate queue for each CPU core.
# If the backlog queue for a core is full, the kernel drops all further incoming packets that the netif_receive_skb() kernel function assigns to this queue. If the server contains a 10 Gbps or faster network adapter or multiple 1 Gbps adapters, tune the backlog queue size to avoid this problem.
# Only improvment on server ? 
sudo echo "net.core.netdev_max_backlog = 2000" > /etc/sysctl.d/10-netdev_max_backlog.conf
sudo sysctl -p /etc/sysctl.d/10-netdev_max_backlog.conf # default is 1000


# Increasing the transmit queue length of a NIC to reduce the number of transmit errors
# these commands are unavail because amazon linux does not have networkanager in their mirrors
# ip -s link show $adapter
# nmcli connection modify Example-Connection link.tx-queue-length 2000
# nmcli connection up Example-Connection
# ip -s link show $adapter

# If irqbalance is not running, usually the CPU core 0 handles most of the interrupts, including network packet receives
sudo systemctl enable --now irqbalance

# Increasing the time SoftIRQs can run on the CPU
awk '{for (i=1; i<=NF; i++) printf strtonum("0x" $i) (i==NF?"\n":" ")}' /proc/net/softnet_stat | column -t
echo If the counters in the third column of the /proc/net/softnet_stat file increment over time, tune the system
# echo "net.core.netdev_budget = 600" > /etc/sysctl.d/10-netdev_budget.conf
# echo "net.core.netdev_budget_usecs = 4000" >> /etc/sysctl.d/10-netdev_budget.conf
# sysctl -p /etc/sysctl.d/10-netdev_budget.conf
# awk '{for (i=1; i<=NF; i++) printf strtonum("0x" $i) (i==NF?"\n":" ")}' /proc/net/softnet_stat | column -t


# C-State / consumption states tuning. The higher the state, the more power saving it wants to be.
cat /sys/module/processor/parameters/max_cstate
sudo grubby --update-kernel=ALL --args="intel_idle.max_cstate=0" # default is 8

