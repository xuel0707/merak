/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

  
 

const bit<16> TYPE_IC = 0x88AB; 
header ic_h {
    bit<1> saved;
    bit<7> type;
    bit<8> dstPoint;
    bit<8> srcPoint;
}

