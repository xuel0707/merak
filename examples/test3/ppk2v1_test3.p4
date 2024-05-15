#include <core.p4>
#define V1MODEL_VERSION 20200914
#include <v1model.p4>

const bit<9> PORT_BIT_MCAST = 254;
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header powerlink_t {
    bit<1> saved;
    bit<7> message_type;
    bit<8> dst_node;
    bit<8> src_node;
}

struct headers {
    ethernet_t  ethernet;
    powerlink_t powerlink;
}

struct metadata {
    bool is_multicast;
}
parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".start") state start {
        transition parse_ethernet;
    }
    @name(".parse_ethernet") state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x88ab: parse_epl;
            default: accept;
        }
    }
    @name(".parse_epl") state parse_epl {
        packet.extract(hdr.powerlink);
        transition accept;
    }
}

control VerifyChecksumImpl(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control IngressImpl(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action _drop() {
        mark_to_drop(standard_metadata);
    }
    action epl_set_egress_port(bit<9> port_num) {
        standard_metadata.egress_port = port_num;
    }
    action epl_multicast(bit<32> mcast_grp) {
        standard_metadata.egress_spec = PORT_BIT_MCAST;
        standard_metadata.bit_mcast = mcast_grp;
        meta.is_multicast = true;
    }
    table powerlink_exact {
        key = {
            hdr.ethernet.dstAddr: exact;
        }
        actions = {
            epl_set_egress_port;
            epl_multicast;
            _drop;
        }
        size = 1024;
        default_action = _drop();
    }
    action change_ethertype() {
        hdr.ethernet.etherType = 0x8100;
    }
    action not_tna_forward() {
        standard_metadata.egress_port = 176;
    }
    apply {
        if (hdr.powerlink.isValid()) {
            powerlink_exact.apply();
            if (meta.is_multicast == true && standard_metadata.ingress_port == standard_metadata.egress_port) {
                mark_to_drop(standard_metadata);
            }
        } else {
            _drop();
        }
    }
}

control EgressImpl(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
        if (meta.is_multicast == true && standard_metadata.ingress_port == standard_metadata.egress_port) {
            mark_to_drop(standard_metadata);
        }
    }
}

control ComputeChecksumImpl(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.powerlink);
    }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;

