#include <core.p4>
#define V1MODEL_VERSION 20180101
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
const bit<16> TYPE_NDN = 0x8624;
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

header mf_guid_t {
    bit<32> mf_type;
    bit<32> src_guid;
    bit<32> dest_guid;
}

header ipv6_t {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_length;
    bit<8>   nextHdr;
    bit<8>   hopLimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct headers {
    ethernet_t          ethernet;
    vlan_t              vlan;
    ipv4_t              ipv4;
    ipv6_t              ipv6;
    mf_guid_t           mf;
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
            TYPE_VLAN: parse_vlan;
            TYPE_IPV4: parse_ipv4;
            0x86dd: parse_ipv6;
            0x27c0: parse_mf;
            default: accept;
        }
    }
    @name(".parse_tsb") state parse_tsb {
        transition accept;
    }
    @name(".parse_ipv6") state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition accept;
    }
    @name(".parse_mf") state parse_mf {
        packet.extract(hdr.mf);
        transition accept;
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
    action _drop() {
        mark_to_drop(standard_metadata);
    }
    action l3_forward(bit<9> port) {
        standard_metadata.egress_port = port;
    }
    action ipv6_forward(bit<9> port) {
        l3_forward(port);
        hdr.ipv6.hopLimit = hdr.ipv6.hopLimit - 1;
    }
    action dest_guid_forward(bit<9> port) {
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
    table ipv6_exact {
        key = {
            hdr.ipv6.dstAddr: exact;
        }
        actions = {
            ipv6_forward;
            _drop;
        }
        size = 1024;
        default_action = _drop();
    }
    table dest_guid_exact {
        actions = {
            dest_guid_forward;
            _drop;
        }
        key = {
            hdr.mf.dest_guid: exact;
        }
        size = 1024;
        default_action = _drop();
    }
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
    action add_vlan_fpga() {
        hdr.vlan.setValid();
        hdr.vlan.vid = 0x1;
        hdr.vlan.etherType = hdr.ethernet.etherType;
    }
    action change_low_vid() {
        hdr.vlan.vid[5:0] = LOW_VID;
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
    action del_vlan_change_ethernet() {
        hdr.ethernet.etherType = hdr.vlan.etherType;
    }
    action cal_low_vid() {
        hdr.vlan.vid[7:6] = 2;
    }
    action extract_vlan_port_forward() {
        standard_metadata.egress_port = (bit<9>)hdr.vlan.vid[7:0];
    }
    action extract_vlan_port_forward_fpga() {
        standard_metadata.egress_port = 167;
    }
    action del_vlan() {
        hdr.vlan.setInvalid();
    }
    apply {
        if (hdr.ipv6.isValid()) {
            ipv6_exact.apply();
        } else if (hdr.mf.isValid()) {
            dest_guid_exact.apply();
        } else if (hdr.ipv4.isValid()) {
            ipv4_forward_table.apply();
        } else if (hdr.ethernet.etherType == TYPE_GEO) {
            add_vlan();
            change_low_vid();
            change_ethertype();
            not_tna_forward_card0();
        } else if (hdr.ethernet.etherType == TYPE_EPL) {
            add_vlan_fpga();
            change_ethertype();
            not_tna_forward_fpga();
        } else if (hdr.ethernet.etherType == TYPE_NDN) {
            add_vlan();
            change_low_vid();
            change_ethertype();
            not_tna_forward_card1();
        } else if (hdr.vlan.etherType == TYPE_GEO) {
            del_vlan_change_ethernet();
            cal_low_vid();
            extract_vlan_port_forward();
            del_vlan();
        } else if (hdr.vlan.etherType == TYPE_EPL) {
            del_vlan_change_ethernet();
            extract_vlan_port_forward_fpga();
            del_vlan();
        } else if (hdr.vlan.etherType == TYPE_NDN) {
            del_vlan_change_ethernet();
            cal_low_vid();
            extract_vlan_port_forward();
            del_vlan();
        } else {
            _drop();
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
        packet.emit(hdr.ipv6);
        packet.emit(hdr.mf);
    }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;

