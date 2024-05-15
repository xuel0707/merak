#!/bin/bash


ARCH=`dpkg --print-architecture`
P4_SRC_DIR=${P4_SRC_DIR-"./examples/"}

SYS=$(uname -a | awk -F ' ' '{print $2}')

print_logo() {
  echo ""
  echo "  Merak Complier Right@2022 zhejianglab"
  echo ""
  echo ""
  /usr/bin/python3 print_logo.py
}


# get counts of p4 by $1
candidate_count() {
	count=$(find "$P4_SRC_DIR" -type f -name "$1.p4*" | wc -l)
	if [ $count -eq 1 ];then
		echo 1
	else
		echo $(find "$P4_SRC_DIR" -type f -name "*$1*.p4*" | wc -l)
	fi 
}

# get name of p4 program
candidates() {
	if [ $(candidate_count $1) -gt 0 ]; then
		echo 
		find "$P4_SRC_DIR" -type f -name "*$1*.p4*" | sed 's#^.*/\([^\.]*\).*$#	\1#g'
	else
		echo "Can not find this P4 program!"
	fi
}

if [ $# -lt 1 ];then
	echo "No p4 file"
	exit 1
fi

trap 'onCtrlC' INT

function onCtrlC(){	
	echo -e "bye" >&8
	sleep 1
	exit 0
}

print_logo

candidates

echo "$P4_SRC_DIR"
  
if [ -d examples/$1 ];then
    rm -rf examples/$1
    mkdir examples/$1
    cp examples/$1.p4 examples/$1/$1.p4
    else
    mkdir examples/$1
    cp examples/$1.p4 examples/$1/$1.p4
fi

/usr/bin/python3 p4c_trans.py examples/$1/$1.p4

cd examples/$1

echo "building" $1 ".."

echo "running system" $SYS

if [ "$SYS" == "sonic" ]; then

  /usr/bin/python3 ../../bsp/cpu/trans2cpu.py examples/$1/$1.p4
  
  /usr/bin/python3 ../../bsp/aster/trans2tna.py examples/$1/$1.p4
  
  /usr/bin/python3 ../../master.py -n ../../examples/$1/v1_$1.p4

  ../../bsp/aster/x312pt/sde9.5.3/sde-9.5.3-stratum/bin/bf-p4c --std p4-16 --arch tna --p4runtime-files $1.pb.txt --p4runtime-force-std-externs --auto-init-metadata asic_$1.p4
  
  ../../bsp/aster/x312pt/tofino.py --ctx-json asic_$1.tofino/pipe/context.json --tofino-bin asic_$1.tofino/pipe/tofino.bin -p asic_$1 -o asic_$1.tofino.bin
      
  ../../bsp/aster/x312pt/pipeline_config --node_id=1 --p4name=asic_$1 --p4info_file=$1.pb.txt --bin_file=./asic_$1.tofino/pipe/tofino.bin --context_file=./asic_$1.tofino/pipe/context.json --p4cookie=3
  
  /usr/bin/stratum_bf -chassis_config_file=/etc/stratum/x86-64-asterfusion-x312p-48y-t-r0/chassis_config.pb.txt -bf_switchd_cfg=/usr/share/stratum/tofino_skip_p4.conf -bf_switchd_background=false -bf_sde_install=/usr/local/sde \
  -enable_onlp=false -forwarding_pipeline_configs_file=examples/$1/asic_$1.pipeline_config.pb.txt
  
fi

if [ "$SYS" == "anos" ]; then
  	/usr/bin/python3 ../../bsp/cpu/trans2cpu.py examples/$1/$1.p4
  	
	/usr/bin/python3 ../../bsp/centec/trans2ctc.py examples/$1/$1.p4
	
	/usr/bin/python3 ../../bsp/fpga/trans2fpga.py examples/$1/$1.p4
	
  	/usr/bin/python3 ../../master.py -n ../../examples/$1/v1_$1.p4
	
	/usr/bin/python3 ../../bsp/centec/anos_client.py init 1
	
	/usr/bin/python3 ../../bsp/centec/anos_client.py init 3
	
	/usr/bin/python3 ../../bsp/centec/anos_client.py init 5
   
       	p4c --target bmv2 --arch v1model asic_$1.p4

fi	

if [ "$SYS" == "ubuntu-YANYU" ]; then

  	/usr/bin/python3 ../../bsp/cpu/trans2cpu.py examples/$1/$1.p4
  	
	/usr/bin/python3 ../../bsp/centec/trans2ctc.py examples/$1/$1.p4
	
	/usr/bin/python3 ../../bsp/fpga/trans2fpga.py examples/$1/$1.p4
	
	/usr/bin/python3 ../../bsp/centec/anos_client.py init 1
	
	/usr/bin/python3 ../../bsp/centec/anos_client.py init 3
	
	/usr/bin/python3 ../../bsp/centec/anos_client.py init 5
	
	p4c --target bmv2 --arch v1model asic_$1.p4
fi	
