import os
import sys
import re
import enum


def trans2ctc(path,file):
    f = open(os.path.join(path, file), 'rt')
    global asicFile
    asicFile = open(os.path.join(path, file[4:]), 'wt')
    global set_once
    set_once=0
    global set_egress
    set_egress=0
    global set_ndn
    set_ndn=0

    line = f.readline()
    while line:
        if "<v1model.p4>" in line:
            asicFile.write(line)
        elif "control IngressImpl(" in line:
            asicFile.write(line)
            
        else:
            asicFile.write(line)
        line = f.readline()

    f.close()
    asicFile.close()

if __name__ == '__main__':
    file = sys.argv[1]
    path,filename = os.path.split(file)
    path="../../"+path

    if os.path.exists(path+"/"+"ppk2asic_{}".format(filename)):
        trans2ctc(path, "ppk2asic_{}".format(filename))
    else:
        print(path+"/"+"ppk2asic_{}".format(filename))
        print("ppk2asic_{} is not existed".format(filename))







