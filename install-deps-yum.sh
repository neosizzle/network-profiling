curr_dir=$(pwd)

# sysperf
sudo yum install dialog ca-certificates jq curl fio wget -y

# sockperf
sudo yum install libtool autoconf g++ -y
cd socketperf
./autogen.sh && ./configure
sudo make && sudo make install
cd $curr_dir

# user-tls-handshake-perf
sudo yum install -y openssl-devel

# ptuning
sudo yum install ethtool gawk -y