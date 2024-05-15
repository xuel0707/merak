#!/bin/bash
OriginHOME=$HOME

export HOME=/opt/Workspace/P4/ppk
sshpass -p $2 ssh root@$1 -tt > /dev/null 2>&1 << remotessh
cd $HOME
touch xinxin.txt
sleep 10
exit
remotessh
export HOME=$OriginHOME 
