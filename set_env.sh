#!/bin/bash

ARCH=`dpkg --print-architecture`


SYS=$(uname -a | awk -F ' ' '{print $2}')

chmod 777 build.sh

if [ "$SYS" == "sonic" ];then
	export SDE=/usr/local/sde/bf-sde-9.5.3
	export SDE_INSTALL=/usr/local/sde
	export PATH=$PATH:$SDE_INSTALL/bin
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SDE_INSTALL/lib
	export P4FLEX=`pwd`

	max_cpu=`cat /proc/cpuinfo | grep "processor" | wc -l`
	build_cpu=`expr $max_cpu - 1`


	#/usr/local/sde/bin/asic-setup.sh
	
	echo 1 > /proc/sys/net/ipv4/ip_forward
	echo 1 > /proc/sys/net/ipv4/conf/eth0/forwarding
	sudo iptables -t nat -F
	sudo iptables -t nat -A POSTROUTING -s 192.168.100.100/24 -j MASQUERADE
	sudo iptables -t nat -A POSTROUTING -s 192.168.101.0/24 -j MASQUERADE
	sudo iptables -t nat -A PREROUTING -p tcp --dport 1022 -j DNAT --to-destination 192.168.100.102:22
	sudo iptables -t nat -A PREROUTING -p tcp --dport 50051 -j DNAT --to-destination 192.168.100.102:50051
	sudo iptables -t nat -A PREROUTING -p tcp --dport 50052 -j DNAT --to-destination 192.168.101.102:50051
	sudo iptables -t nat -A PREROUTING -p tcp --dport 2022 -j DNAT --to-destination 192.168.101.102:22
fi


if [ "$SYS" == "anos" ];then
	echo $SYS
fi

if [ "$SYS" == "ubuntu-YANYU" ];then
	echo $SYS
fi


