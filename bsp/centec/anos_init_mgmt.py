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
ctc_shell_flag = False

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

def pexpect_get_command_result(cmd, sleep_time = 0, prompt = 'ctc'):
    process.sendline(cmd)
    ret = process.expect(prompt)
    after_output = process.after.strip().decode()
    before_output = process.before.strip().decode()
    output = after_output + before_output
    log_debug("%s" % (output))
    return ret, output

def enter_ctc_shell(sleep_time = 0, exec_timeout = 60):
    result_str = ""
    global process
    global ctc_shell_flag
    if ctc_shell_flag:
        return True

    process = pexpect.spawn("ctc_shell")
    ret = process.expect([pexpect.TIMEOUT, "ctc", pexpect.EOF], timeout = exec_timeout)
    if ret == 0:
        result_str += process.before.strip().decode()
        log_debug(result_str)
        return False

    ctc_shell_flag = True
    return True

def set_all_mfmt_pre(sleep_time = 0):
    if enter_ctc_shell() is False:
        log_debug("enter_ctc_shell fail")
        return

    cmd_list = []
    # COMe0
    cmd_list.append("chip set serdes 24 ffe mode user-define c0 0 c1 20 c2 61")
    cmd_list.append("chip set serdes 25 ffe mode user-define c0 0 c1 20 c2 61")
    # COMe1
    cmd_list.append("chip set serdes 26 ffe mode user-define c0 0 c1 20 c2 61")
    cmd_list.append("chip set serdes 27 ffe mode user-define c0 0 c1 20 c2 61")
    # COMe2
    cmd_list.append("chip set serdes 28 ffe mode user-define c0 0 c1 20 c2 61")
    cmd_list.append("chip set serdes 29 ffe mode user-define c0 0 c1 20 c2 61")
    # COMe3
    cmd_list.append("chip set serdes 30 ffe mode user-define c0 0 c1 20 c2 61")
    cmd_list.append("chip set serdes 31 ffe mode user-define c0 0 c1 20 c2 61")
    for cmd in cmd_list:
        pexpect_get_command_result(cmd, process)
    time.sleep(sleep_time)

if __name__ == "__main__":
    set_all_mfmt_pre()