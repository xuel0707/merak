#include <core.p4>
#define V1MODEL_VERSION 20180101
#include <v1model.p4>

const bit<16> TYPE_IC = 0x88ab;
header ic_h {
    bit<1> saved;
    bit<7> type;
    bit<8> dstPoint;
    bit<8> srcPoint;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct headers {
    ethernet_t ethernet;
    ic_h       ic;
}

struct metadata {
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".start") state start {
        transition select(standard_metadata.ingress_port) {
            default: parse_ethernet;
        }
    }
    @name(".parse_ethernet") state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IC: parse_ic;
            default: accept;
        }
    }
    @name(".parse_ic") state parse_ic {
        packet.extract(hdr.ic);
        transition accept;
    }
}

control VerifyChecksumImpl(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control IngressImpl(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action action1() {
        standard_metadata.egress_port = 0x1;
    }
    table ic_exact {
        key = {
            hdr.ethernet.etherType: exact;
        }
        actions = {
            action1;
            NoAction;
        }
        const default_action = NoAction;
    }
    apply {
        if (hdr.ic.isValid()) {
            ic_exact.apply();
    }
}

control ComputeChecksumImpl(inout headers hdr, inout metadata meta) {
    apply {
        ;
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ic);
    }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;

