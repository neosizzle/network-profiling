# Run this script once and reboot
# https://rigtorp.se/low-latency-guide/
# https://talawah.io/blog/extreme-http-performance-tuning-one-point-two-million

# NOTE: We have 16 cores in prod
# nohz_full - disable timers on core
# rch_nocb - disable rcu callbacks (for queuing lock operations) on core
# isolcpu - isolate cores from kernel scheduler
# mitigations - disable CPU security mitigations
# pti -  Control Page Table Isolation. removes hardening, but improves performance of system calls and interrupts.
# use cat /proc/cmdline to verify
# echo -n "Please enter maximum CPU ID: "
# read max_id
# sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"\(.*\)\"/\"\1 isolcpus=1-$max_id nohz_full=1-$max_id rcu_nocbs=1-$max_id mitigations=off pti=off\"/" /etc/default/grub
sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"\(.*\)\"/\"\1 mitigations=off pti=off\"/" /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
echo "Please reboot instance to apply kernel parameters"