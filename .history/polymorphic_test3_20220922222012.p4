/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#ifdef UDEF_FPGA
const bit<16> TYPE_IC = 0x88AB;   
header ic_h {
    bit<1> saved;
    bit<7> type;
    bit<8> dstPoint;
    bit<8> srcPoint;
}
#endif

#ifdef UDEF_ASIC
const bit<16> TYPE_IPV4 = 0x800;   

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}
#endif 

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

#ifdef UDEF_ASIC
@controller_header("packet_in")
header packet_in_header_t {
    bit<9> ingress_port;
    bit<7> _padding;
}

@controller_header("packet_out")
header packet_out_header_t {
    bit<9> egress_port;
    bit<7> _padding;
}
#endif



struct headers {
    packet_out_header_t packet_out;
    packet_in_header_t packet_in;
    ethernet_t ethernet;
    ipv4_t     ipv4;
    ic_h ic;
}

struct metadata {

}


parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".start") state start {
        transition select(standard_metadata.ingress_port) {
            CPU_PORT: parse_packet_out;
            default: parse_ethernet;
        } 
    }

    @name(".parse_packet_out") state parse_packet_out {
        packet.extract(hdr.packet_out);
        transition parse_ethernet;
    }

    @name(".parse_ethernet") state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            0x88ab: parse_ic;
            default: accept;
        }
    }

    @name(".parse_ipv4") state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
    state parser_ic {
        packet.extract(hdr.ic);
        transition accept;
    }
}

control VerifyChecksumImpl(inout headers hdr, inout metadata meta) {
    apply {
    }
}


control IngressImpl(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action set_egress_port(bit<9> port) {
        standard_metadata.egress_port = port;
    }
    table ipv4_forward_table {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            set_egress_port;
             @defaultonly drop;
        }
        const default_action = drop;
        size = 1024;
    }

    action action1() {
        standard_metadata.egress_port = 0x1;
    }

    table ic_exact {
        key = {hdr.ethernet.etherType:exact;
             }
        actions = {
            action1; 
            NoAction;
        }
        const default_action = NoAction;
    }
    apply {
        if (hdr.ethernet.etherType == TYPE_IC){
            ic_exact.apply();
        }
        if (hdr.ethernet.etherType == TYPE_IPV4){
            ipv4_forward_table.apply();
        }
    }
}

control EgressImpl(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

control ComputeChecksumImpl(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
	    packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ic);
        packet.emit(hdr.ipv4);
    }
}



V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;


