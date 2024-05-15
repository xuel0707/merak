# -*- coding: UTF-8 -*-
#!/usr/bin/python

import re
import sys
import time
import click
import socket
import syslog
import pexpect
import datetime
import traceback
import subprocess

process = None
anos_cli_flag = False
ctc_shell_flag = False

socket_bind_ip = "localhost"
#socket_bind_ip = "10.11.37.46"
socket_bind_port = 8001

socket_bind_connection_max = 5
log_also_print_to_console = True

def log_debug(msg):
    SYSLOG_IDENTIFIER = "ANOS_TEST"
    funcName = sys._getframe().f_back.f_code.co_name
    lineNumber = sys._getframe().f_back.f_lineno
    dt_ms = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
    info_str = dt_ms + "| DEBUG : " + funcName + ": " + str(lineNumber)
    log_info_gather = "%-40s| %s" % (info_str, str(msg))
    try:
        syslog.openlog(SYSLOG_IDENTIFIER)
        syslog.syslog(syslog.LOG_DEBUG, msg)
        syslog.closelog()

        if log_also_print_to_console:
            click.echo(log_info_gather)
    except Exception as except_result:
        msg = traceback.format_exc()
        print("Exception_info:\n%s" % msg)

def pexpect_get_command_result(cmd, sleep_time = 0, prompt = 'anos'):
    process.sendline(cmd)
    ret = process.expect(prompt)
    after_output = process.after.strip().decode()
    before_output = process.before.strip().decode()
    output = after_output + before_output
    log_debug("%s" % (output))
    return ret, output

def enter_anos_cli(sleep_time = 0, exec_timeout = 60):
    result_str = ""
    global process
    global anos_cli_flag
    if anos_cli_flag:
        return True

    process = pexpect.spawn("anos_cli")
    ret = process.expect([pexpect.TIMEOUT, "anos", pexpect.EOF], timeout = exec_timeout)
    if ret == 0:
        result_str += process.before.strip().decode()
        log_debug(result_str)
        return False

    anos_cli_flag = True
    return True

def shudown_port(port, sleep_time = 0):
    if enter_anos_cli() is False:
        log_debug("enter_anos_cli fail")
        return

    cmd_list = []
    cmd_list.append("configure terminal")
    cmd_list.append("interface %s" % port)
    cmd_list.append("shutdown")
    cmd_list.append("end")
    for cmd in cmd_list:
        pexpect_get_command_result(cmd, process)
    time.sleep(sleep_time)

def no_shudown_port_and_access(port, sleep_time = 0):
    if enter_anos_cli() is False:
        log_debug("enter_anos_cli fail")
        return

    cmd_list = []
    cmd_list.append("configure terminal")
    cmd_list.append("interface %s" % port)
    cmd_list.append("no shutdown")
    cmd_list.append("port link-type access")
    cmd_list.append("end")
    for cmd in cmd_list:
        pexpect_get_command_result(cmd, process)
    time.sleep(sleep_time)

def init_env():
    try:
        no_shudown_port_and_access("GE0/0/1")
        no_shudown_port_and_access("GE0/0/47")
        no_shudown_port_and_access("GE0/0/48")
    except Exception as e:
        log_debug(traceback.format_exc())

def recover_env():
    try:
        shudown_port("GE0/0/1")
        shudown_port("GE0/0/47")
        shudown_port("GE0/0/48")
    except Exception as e:
        log_debug(traceback.format_exc())

def start_server():
    log_debug("Server is starting")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind((socket_bind_ip, socket_bind_port))
    sock.listen(socket_bind_connection_max)
    log_debug("Server is listenting %s:%s, with max connection %s" % (
                socket_bind_ip, socket_bind_port, socket_bind_connection_max))
    while True:
        connection,address = sock.accept()
        try:
            connection.settimeout(50)
            buf = str(connection.recv(1024).decode(encoding='utf-8'))
            log_debug("Get value " + buf)
            if buf == 'init':
                init_env()
            else:
                recover_env()
        except socket.timeout:
            log_debug("time out")
        log_debug("closing one connection")
    connection.close()

if __name__ == "__main__":
    start_server()