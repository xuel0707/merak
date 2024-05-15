import os
import sys
import re
import enum

def trans2cpu(path,file):
    f = open(os.path.join(path, file), 'rt')
    global ppkFile
    ppkFile = open(os.path.join(path, file[4:]), 'wt')
    global set_encrypt
    set_encrypt=0
    global set_decrypt
    set_decrypt=0
    global set_geo_encrypt
    set_geo_encrypt=0
    global set_geo_decrypt
    set_geo_decrypt=0

    line = f.readline()
    while line:
        if "#define V1MODEL_ENCRYPT 1" in line:
            set_encrypt=1
            ppkFile.write(line)
        elif "#define V1MODEL_DECRYPT 1" in line:
            set_decrypt=1
            ppkFile.write(line)
        elif "#define V1MODEL_GEO_ENCRYPT 1" in line:
            set_geo_encrypt=1
            ppkFile.write(line)
        elif "#define V1MODEL_GEO_DECRYPT 1" in line:
            set_geo_decrypt=1
            ppkFile.write(line)
        elif "#include <v1model.p4>" in line:
            if set_encrypt == 1:
                line = "#include <v1model_encrypt.p4>"
            if set_decrypt == 1:
                line = "#include <v1model_encrypt.p4>"
            if set_geo_encrypt == 1:
                line = "#include <v1model_encrypt.p4>"
            if set_geo_decrypt == 1:
                line = "#include <v1model_encrypt.p4>"
            ppkFile.write(line)
        elif "register<bit<32>, bit<32>>(1024)" in line:
            line = ""
            ppkFile.write(line)
        elif "V1Switch" in line:
            if set_encrypt == 1:
                line = "control EncryptWithPayloadImpl(inout headers hdr, inout metadata meta) {\r\
        apply { \r\
            if (hdr.ipv4.isValid()) {\r\
                encrypt_with_payload();\r\
            }\r\
        }\r\
}\r\n\n\
V1Switch(\r\
    ParserImpl(),\r\
    VerifyChecksumImpl(),\r\
    IngressImpl(),\r\
    EgressImpl(),\r\
    EncryptWithPayloadImpl(),\r\
    ComputeChecksumImpl(),\r\
    DeparserImpl()) main;\n"

            if set_decrypt == 1:
                line = "control DecryptWithPayloadImpl(inout headers hdr, inout metadata meta) {\r\
        apply { \r\
            if (hdr.ipv4.isValid()) {\r\
                decrypt_with_payload();\r\
            }\r\
        }\r\
}\r\n\n\
V1Switch(\r\
    ParserImpl(),\r\
    VerifyChecksumImpl(),\r\
    IngressImpl(),\r\
    EgressImpl(),\r\
    DecryptWithPayloadImpl(),\r\
    ComputeChecksumImpl(),\r\
    DeparserImpl()) main;\n"

            if set_geo_encrypt == 1:
                line = "control EncryptWithPayloadImpl(inout headers hdr, inout metadata meta) {\r\
        apply { \r\
            if (hdr.geo.isValid()) {\r\
                encrypt_with_payload();\r\
            }\r\
        }\r\
}\r\n\n\
V1Switch(\r\
    ParserImpl(),\r\
    VerifyChecksumImpl(),\r\
    IngressImpl(),\r\
    EgressImpl(),\r\
    EncryptWithPayloadImpl(),\r\
    ComputeChecksumImpl(),\r\
    DeparserImpl()) main;\n"

            if set_geo_decrypt == 1:
                line = "control DecryptWithPayloadImpl(inout headers hdr, inout metadata meta) {\r\
        apply { \r\
            if (hdr.geo.isValid()) {\r\
                decrypt_with_payload();\r\
            }\r\
        }\r\
}\r\n\n\
V1Switch(\r\
    ParserImpl(),\r\
    VerifyChecksumImpl(),\r\
    IngressImpl(),\r\
    EgressImpl(),\r\
    DecryptWithPayloadImpl(),\r\
    ComputeChecksumImpl(),\r\
    DeparserImpl()) main;\n"
            ppkFile.write(line)
                        
        else:
            ppkFile.write(line)
        line = f.readline()

    f.close()
    ppkFile.close()


if __name__ == '__main__':
    file = sys.argv[1]
    path,filename = os.path.split(file)
    path="../../"+path

    if os.path.exists(path+"/"+"ppk2v1_{}".format(filename)):
        trans2cpu(path, "ppk2v1_{}".format(filename))
    else:
        print("ppk2v1_{} is not existed".format(filename))




