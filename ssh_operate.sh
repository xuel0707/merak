#!/bin/bash
OriginHOME=$HOME

export HOME=/opt/Workspace/P4/ppk
sshpass -p $2 ssh root@$1 -tt > /dev/null 2>&1 << remotessh
cd $HOME
nohup ./slave.py &
sleep 10m
exit
remotessh
export HOME=$OriginHOME 
