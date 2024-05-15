import os
import sys
import re
import enum

def trans2fpga(path,file):
    f = open(os.path.join(path, file), 'rt')
    global fpgaFile
    fpgaFile = open(os.path.join(path, file[4:]), 'wt')
    global hc_isvalid
    hc_isvalid=0 
    line = f.readline()
    while line:
        if "#include <v1model.p4>" in line:
            line = "#include <fpga_model.p4>"
            fpgaFile.write(line)
        elif "parser ParserImpl" in line:
            line =  "parser ParserImpl(packet_in packet,out headers hdr,inout standard_metadata_t standard_metadata) {\n"
            fpgaFile.write(line)
        elif "start" in line:
            line= "    state start {\r\
            packet.extract(hdr.ethernet);\r\
            transition select(hdr.ethernet.etherType){\r\
            TYPE_IC: parse_ic;\r\
            default: accept;\n"
            fpgaFile.write(line)
        elif "transition select(standard_metadata.ingress_port)" in line:
            line =  ""
            fpgaFile.write(line)   
        elif " default: parse_ethernet;" in line:   
            line =  ""
            fpgaFile.write(line)
        elif "mark_to_drop" in line:   
            line =  ""
            fpgaFile.write(line)
        elif "standard_metadata.egress_port = port" in line:   
            line =  ""
            fpgaFile.write(line)
        elif "standard_metadata.egress_spec = PORT_BIT_MCAST" in line:   
            line =  ""
            fpgaFile.write(line)
        elif "standard_metadata.bit_mcast = mcast_grp" in line:   
            line =  ""
            fpgaFile.write(line)
        elif "control ComputeChecksumImpl" in line:
            line =  "control ComputeChecksumImpl(inout headers hdr) {\n"    
            fpgaFile.write(line)  
        elif "control IngressImpl" in line:
            line =  "control IngressImpl(inout headers hdr, inout standard_metadata_t standard_metadata) {\n"    
            fpgaFile.write(line)
        elif "if (hdr.ic.isValid()) {" in line:
            line = ""
            fpgaFile.write(line)
        elif "V1Switch" in line:
            line =  "FPGAModel(\n\
    ParserImpl(),\n\
    IngressImpl(),\n\
    ComputeChecksumImpl(),\n\
    DeparserImpl()\n\
    ) main;\n\n\n"
            fpgaFile.write(line)
        else:
            fpgaFile.write(line)
        line = f.readline()

    f.close()
    fpgaFile.close()

if __name__ == '__main__':
    file = sys.argv[1]
    path,filename = os.path.split(file)
    path="../../"+path

    if os.path.exists(path+"/"+"ppk2fpga_{}".format(filename)):
        trans2fpga(path, "ppk2fpga_{}".format(filename))
    else:
        print("ppk2fpga_{} is not existed".format(filename))



