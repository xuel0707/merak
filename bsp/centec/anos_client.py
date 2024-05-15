# -*- coding: UTF-8 -*-
#!/usr/bin/python
import sys
import socket
import traceback

socket_bind_ip = "localhost"
#socket_bind_ip = "10.11.37.46"
socket_bind_port = 8001

reference ="reference:\n\
        python anos_test_client.py [init|stop] <port_num>\n\n\
eg:  1. python anos_test_client.py init 1\n\
     2. python anos_test_client.py stop 1\n"

def show_support_test_fun():
    print(reference)

def start_client():
    try:
        if len(sys.argv) < 3:
            show_support_test_fun()
            return
        msg = sys.argv[1] + " " + sys.argv[2]
        print(msg)
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((socket_bind_ip, socket_bind_port))
        sock.send(msg.encode(encoding='utf-8'))
        sock.close()
    except Exception as e:
        show_support_test_fun()
        print(traceback.format_exc())

if __name__ == '__main__':
    start_client()
