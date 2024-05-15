#include <core.p4>
#define V1MODEL_VERSION 20200914
#include <v1model.p4>

const bit<9> PORT_BIT_MCAST = 254;
const bit<16> TYPE_VLAN = 0x8100;
const bit<16> TYPE_IPV4 = 0x800;
const bit<9> GHC0_IN = 44;
const bit<9> GHC1_IN = 176;
const bit<6> LOW_VID = 0x3f;
const bit<16> TYPE_IPV6 = 0x86dd;
const bit<16> TYPE_GEO = 0x8947;
const bit<16> TYPE_MF = 0x27c0;
const bit<16> TYPE_EPL = 0x88ab;
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header vlan_t {
    bit<3>  typeID;
    bit<1>  cfi;
    bit<12> vid;
    bit<16> etherType;
}

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

struct headers {
    ethernet_t  ethernet;
    vlan_t      vlan;
    ipv4_t      ipv4;
}

struct metadata {
}
parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".start") state start {
        transition parse_ethernet;
    }
    @name(".parse_ethernet") state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_VLAN: parse_vlan;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    @name(".parse_vlan") state parse_vlan {
        packet.extract(hdr.vlan);
        transition select(hdr.vlan.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    @name(".parse_ipv4") state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

control VerifyChecksumImpl(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control IngressImpl(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action ipv4_set_egress(bit<9> port) {
        standard_metadata.egress_port = port;
    }
    action ipv4_drop() {
        mark_to_drop(standard_metadata);
    }
    table ipv4_forward_table {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_set_egress;
            ipv4_drop;
        }
        default_action = ipv4_drop();
        size = 1024;
    }
    action add_vlan() {
        hdr.vlan.setValid();
        hdr.vlan.vid[11:6] = standard_metadata.ingress_port[5:0];
        hdr.vlan.etherType = hdr.ethernet.etherType;
    }
    action change_low_vid() {
        hdr.vlan.vid[5:0] = LOW_VID;
    }
    action change_ethertype() {
        hdr.ethernet.etherType = 0x8100;
    }
    action not_tna_forward() {
        standard_metadata.egress_port = 176;
    }
    action del_vlan_change_ethernet() {
        hdr.ethernet.etherType = hdr.vlan.etherType;
    }
    action cal_low_vid() {
        hdr.vlan.vid[7:6] = 2;
    }
    action extract_vlan_port_forward() {
        standard_metadata.egress_port = (bit<9>)hdr.vlan.vid[7:0];
    }
    action del_vlan() {
        hdr.vlan.setInvalid();
    }
    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_forward_table.apply();
        } else if (hdr.ethernet.etherType == TYPE_GEO) {
            add_vlan();
            change_low_vid();
            change_ethertype();
            not_tna_forward();
        } else if (hdr.ethernet.etherType == TYPE_IPV6) {
            add_vlan();
            change_low_vid();
            change_ethertype();
            not_tna_forward();
        } else if (hdr.ethernet.etherType == TYPE_MF) {
            add_vlan();
            change_low_vid();
            change_ethertype();
            not_tna_forward();
        } else if (hdr.ethernet.etherType == TYPE_EPL) {
            not_tna_forward();
        } else if (hdr.vlan.etherType == TYPE_MF) {
            del_vlan_change_ethernet();
            cal_low_vid();
            extract_vlan_port_forward();
            del_vlan();
        } else if (hdr.vlan.etherType == TYPE_GEO) {
            del_vlan_change_ethernet();
            cal_low_vid();
            extract_vlan_port_forward();
            del_vlan();
        } else if (hdr.vlan.etherType == TYPE_IPV6) {
            del_vlan_change_ethernet();
            cal_low_vid();
            extract_vlan_port_forward();
            del_vlan();
        } else if (hdr.vlan.etherType == TYPE_EPL) {
            del_vlan_change_ethernet();
            cal_low_vid();
            extract_vlan_port_forward();
            del_vlan();
        } else {
        }
    }
}

control EgressImpl(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
    }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;

