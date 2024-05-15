#include <core.p4>
#define V1MODEL_VERSION 20180101
#include <v1model.p4>

const bit<9> PORT_BIT_MCAST = 254;
const bit<16> TYPE_TPID = 0x8100;
const bit<16> TYPE_IC = 0x88ab;
header vlan_tag_h {
    bit<16> vid;
    bit<16> etherType;
}

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
    ethernet_t          ethernet;
    vlan_tag_h          vlan_tag;
    ic_h                ic;
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
            default: accept;
        }
    }
    @name(".parse_tsb") state parse_tsb {
        transition accept;
    }
    state parser_vlan_tag {
        packet.extract(hdr.vlan_tag);
        transition select(hdr.vlan_tag.etherType) {
            TYPE_IC: parser_ic;
            default: accept;
        }
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
    action l3_forward(bit<9> port) {
        standard_metadata.egress_port = port;
    }
    action epl_multicast(bit<32> mcast_grp) {
        standard_metadata.egress_spec = PORT_BIT_MCAST;
        standard_metadata.bit_mcast = mcast_grp;
    }
    action epl_set_egress_port(bit<9> port_num) {
        standard_metadata.egress_port = port_num;
    }
    action set_egress_port(bit<9> port_num) {
        standard_metadata.egress_port = port_num;
    }
    action action1() {
        standard_metadata.egress_port = 0x1;
        hdr.vlan_tag.vid = 0x2;
    }
    table ic_exact {
        key = {
            hdr.ethernet.etherType: exact;
            hdr.vlan_tag.etherType: exact;
        }
        actions = {
            action1;
            NoAction;
        }
        const default_action = NoAction;
    }
    action change_ethertype() {
        hdr.ethernet.etherType = 0x8100;
    }
    action not_tna_forward_card0() {
        standard_metadata.egress_port = 44;
    }
    action not_tna_forward_card1() {
        standard_metadata.egress_port = 176;
    }
    action not_tna_forward_fpga() {
        standard_metadata.egress_port = 12;
    }
    action extract_vlan_port_forward_fpga() {
        standard_metadata.egress_port = 167;
    }
    apply {
        if (hdr.ic.isValid()) {
            ic_exact.apply();
        } else {
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
        packet.emit(hdr.ethernet);
        packet.emit(hdr.vlan_tag);
        packet.emit(hdr.ic);
    }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;

