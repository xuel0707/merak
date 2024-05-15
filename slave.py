#!/usr/bin/env python
#coding=utf-8

import platform
import os
import signal
import threading
import socket 
import json
import struct
import time
import subprocess
import sys

import threading, signal

is_exit = False
local_ipaddr = ""


def handler(signum, frame):
    global is_exit
    is_exit = True
    print ("receive a signal %d, is_exit = %d"%(signum, is_exit))
    sys.exit(0)


def get_interface_info(interface):
        mac_address = subprocess.check_output("ifconfig " + interface + " | grep ether | awk -F ' ' '{print $2}'", shell=True).decode('utf-8')
        ip_address = subprocess.check_output("ifconfig " + interface + " | grep 'inet ' | awk '{print $2}'", shell=True).decode('utf-8')
        return mac_address, ip_address    

class slaveThread(threading.Thread):
    def __init__(self,threadID,name):
        threading.Thread.__init__(self)
        self.threadID = threadID
        self.name = name
  
    
    def run(self):
            #master to slave server tcp
            
            tcp_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            tcp_server.bind((local_ipaddr,9000))
            tcp_server.listen(128)
            
            try:
                global is_exit
                while not is_exit:
                    # 等待新的客户端连接
                    client_socket, clientAddr = tcp_server.accept()
                    
                    buffsize = 1024
                    filename = "examples/"

                    if is_exit:
                        print ("receive a signal, slave thread is exiting")
                        break
                    else:
                        print (".")
                    
                    while True:
                        

                        # 接收报头的长度
                        head_struct = client_socket.recv(4) 
                        if head_struct:       
                            print('connectd...')
                        else:
                            break
                        # 解析出报头的字符串大小
                        head_len = struct.unpack('i', head_struct)[0]
                        # 接收长度为head_len的报头内容的信息 (包含文件大小,文件名的内容)
                        data = client_socket.recv(head_len)     
                        head_dir = json.loads(data.decode('utf-8'))
                        
                        filesize_b = head_dir['filesize_bytes']
                        
                        filename = filename + head_dir['filename'].split('v1_')[1]    
                    
                        recv_len = 0
                        recv_mesg = b''
                        if os.path.isfile(filename):
                            os.system('rm -rf '+filename)
                            print('remove '+filename)

                        f = open(filename, 'wb')   
                        while recv_len < filesize_b:                   
                            if filesize_b - recv_len > buffsize:
                        
                                recv_mesg = client_socket.recv(buffsize)
                        
                                f.write(recv_mesg)
                        
                                recv_len += len(recv_mesg)       
                            else:
                        
                                recv_mesg = client_socket.recv(filesize_b - recv_len)
                    
                                recv_len += len(recv_mesg)
                        
                                f.write(recv_mesg)   
                    
                        f.close()
                                                                
                    client_socket.close()
                    time.sleep(0.001)
                    os.system('. ./ppk_en.sh;./ppk.sh :'+filename.split("/")[1].split(".p4")[0])  

            except BaseException as e:
                print(repr(e))

            finally:
                tcp_server.close()


def main():
    MACH    =   platform.machine()
    print("Current platform machine:")
    print(MACH)

    if MACH == "x86_64":
        pass

    try:
        interface_list = subprocess.check_output('ifconfig | grep flags | cut -d ":" -f 1', stderr=subprocess.STDOUT, shell=True).decode('utf-8').split("\n")[0:-1]
        for interface in interface_list:
            mac_address, ip_address = get_interface_info(interface)
            if not ip_address:
                continue
            if not mac_address:
                continue
            global local_ipaddr
            local_ipaddr=ip_address
            print("******Interface [ %s ] information as follows:\n" % interface)
            print("\t\tMAC address: %s" % mac_address)
            print("\t\tIP address: %s\n" % local_ipaddr)
            print("="*100)
    except BaseException as e:
        print(repr(e))
        sys.exit()

    thread1 = slaveThread(1,"slaveThread")
    thread1.setDaemon(True)
    thread1.start()
    while 1:
        alive=False
        alive=alive or thread1.is_alive()
        if not alive:
            break

if __name__ == '__main__':
    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGTERM, handler)
    main()

