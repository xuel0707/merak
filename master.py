#!/usr/bin/env python
#coding=utf-8

import argparse
import platform
import os
import struct
import json
import sys
import time
import socket


def main():
    parser = argparse.ArgumentParser(description="Demo of argparse")
    parser.add_argument('-n','--name', default=' na ')
    parser.add_argument('-p','--path', default=' pa ')
    args = parser.parse_args()

    MACH=platform.machine()
    print("current platform machine:")
    print(MACH)
    
    if MACH == "x86_64":
        pass

    filename=args.name

    # 初始化套接字
    tcp_socket = socket.socket(socket.AF_INET,socket.SOCK_STREAM) 

    # 建立链接他，要传入链接的服务器 IP 和 Port
    tcp_socket.connect(("192.168.101.102",9000)) 

    filemesg = filename.strip()             
    filesize_bytes = os.path.getsize(filemesg) # 得到文件的大小,字节               
    filename = filemesg                
    dirc = {           
           'filename': filename,       
           'filesize_bytes': filesize_bytes,
    }               
    head_info = json.dumps(dirc)  # 将字典转换成字符串                
    head_info_len = struct.pack('i', len(head_info)) 
    #  将字符串的长度打包                
    #   先将报头转换成字符串(json.dumps), 再将字符串的长度打包                
    #   发送报头长度,发送报头内容,最后放真是内容                
    #   报头内容包括文件名,文件信息,报头                
    #   接收时:先接收4个字节的报头长度,                
    #   将报头长度解压,得到头部信息的大小,在接收头部信息, 反序列化(json.loads)                
    #   最后接收真实文件                
    tcp_socket.send(head_info_len)  # 发送head_info的长度                
    tcp_socket.send(head_info.encode('utf-8'))       
    #   发送真是信息                
    with open(filemesg, 'rb') as f:                       
           data = f.read()                    
           tcp_socket.sendall(data) 

    tcp_socket.close()

    # # 初始化套接字
    tcp_socket2 = socket.socket(socket.AF_INET,socket.SOCK_STREAM) 

    # 建立链接他，要传入链接的服务器 IP 和 Port
    tcp_socket2.connect(("192.168.101.102",9000)) 

    filemesg2 = filename.strip()             
    filesize_bytes2 = os.path.getsize(filemesg2) # 得到文件的大小,字节               
    filename2 = filemesg2                
    dirc2 = {           
            'filename': filename2,       
            'filesize_bytes': filesize_bytes2,
    }               
    head_info2 = json.dumps(dirc2)  # 将字典转换成字符串                
    head_info_len2 = struct.pack('i', len(head_info2)) 
    #  将字符串的长度打包                
    #   先将报头转换成字符串(json.dumps), 再将字符串的长度打包                
    #   发送报头长度,发送报头内容,最后放真是内容                
    #   报头内容包括文件名,文件信息,报头                
    #   接收时:先接收4个字节的报头长度,                
    #   将报头长度解压,得到头部信息的大小,在接收头部信息, 反序列化(json.loads)                
    #   最后接收真实文件                
    tcp_socket2.send(head_info_len2)  # 发送head_info的长度                
    tcp_socket2.send(head_info2.encode('utf-8'))       
    #   发送真是信息                
    with open(filemesg2, 'rb') as f2:                       
            data2 = f2.read()                    
            tcp_socket2.sendall(data2) 

    tcp_socket2.close()

if __name__ == '__main__':
    try:
        main()
    except Exception as ex:
        print(repr(ex))


