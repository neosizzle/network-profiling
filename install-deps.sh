curr_dir=$(pwd)

# sysperf
sudo apt install dialog ca-certificates jq curl fio wget -y

# sockperf
sudo apt-get install libtool autoconf -y
cd socketperf
./autogen.sh && ./configure
sudo make && sudo make install
cd $curr_dir

# ptuning
sudo apt install ethtool gawk -y