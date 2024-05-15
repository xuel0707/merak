#include <core.p4>
#define V1MODEL_VERSION 20180101
#include <v1model.p4>

const bit<9> PORT_BIT_MCAST = 254;
const bit<4> TYPE_geo_beacon = 0x1;
const bit<4> TYPE_geo_gbc = 0x4;
const bit<4> TYPE_geo_tsb = 0x5;
const bit<9> PORT_ONOS = 255;
const bit<9> CPU_PORT = 255;
header geo_t {
    bit<4>  version;
    bit<4>  nh_basic;
    bit<8>  reserved_basic;
    bit<8>  lt;
    bit<8>  rhl;
    bit<4>  nh_common;
    bit<4>  reserved_common_a;
    bit<4>  ht;
    bit<4>  hst;
    bit<8>  tc;
    bit<8>  flag;
    bit<16> pl;
    bit<8>  mhl;
    bit<8>  reserved_common_b;
}

header gbc_t {
    bit<16> sn;
    bit<16> reserved_gbc_a;
    bit<64> gnaddr;
    bit<32> tst;
    bit<32> lat;
    bit<32> longg;
    bit<1>  pai;
    bit<15> s;
    bit<16> h;
    bit<32> geoAreaPosLat;
    bit<32> geoAreaPosLon;
    bit<16> disa;
    bit<16> disb;
    bit<16> angle;
    bit<16> reserved_gbc_b;
}

header beacon_t {
    bit<64> gnaddr;
    bit<32> tst;
    bit<32> lat;
    bit<32> longg;
    bit<1>  pai;
    bit<15> s;
    bit<16> h;
}

header powerlink_t {
    bit<1> saved;
    bit<7> message_type;
    bit<8> dst_node;
    bit<8> src_node;
}

@controller_header("packet_in") header packet_in_header_t {
    bit<9> ingress_port;
    bit<7> _padding;
}

@controller_header("packet_out") header packet_out_header_t {
    bit<9> egress_port;
    bit<7> _padding;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct headers {
    ethernet_t          ethernet;
    geo_t               geo;
    gbc_t               gbc;
    beacon_t            beacon;
    powerlink_t         powerlink;
    packet_out_header_t packet_out;
    packet_in_header_t  packet_in;
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
            0x8947: parse_geo;
            0x88ab: parse_epl;
            default: accept;
        }
    }
    @name(".parse_geo") state parse_geo {
        packet.extract(hdr.geo);
        transition select(hdr.geo.ht) {
            TYPE_geo_beacon: parse_beacon;
            TYPE_geo_gbc: parse_gbc;
            TYPE_geo_tsb: parse_tsb;
            default: accept;
        }
    }
    @name(".parse_beacon") state parse_beacon {
        packet.extract(hdr.beacon);
        transition accept;
    }
    @name(".parse_gbc") state parse_gbc {
        packet.extract(hdr.gbc);
        transition accept;
    }
    @name(".parse_tsb") state parse_tsb {
        transition accept;
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
    action geo_unicast(bit<9> port) {
        standard_metadata.egress_spec = port;
    }
    action l3_forward(bit<9> port) {
        standard_metadata.egress_port = port;
    }
    action geo_fwd2ONOS() {
        standard_metadata.egress_spec = PORT_ONOS;
    }
    action geo_multicast(bit<32> bitcast) {
        standard_metadata.egress_spec = PORT_BIT_MCAST;
        standard_metadata.bit_mcast = bitcast;
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
    table gbc_exact {
        actions = {
            geo_multicast;
            geo_unicast;
            geo_fwd2ONOS;
        }
        key = {
            hdr.gbc.geoAreaPosLat: exact;
            hdr.gbc.geoAreaPosLon: exact;
            hdr.gbc.disa         : exact;
            hdr.gbc.disb         : exact;
        }
        size = 1024;
        default_action = geo_fwd2ONOS();
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
        if (hdr.gbc.isValid()) {
            gbc_exact.apply();
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
        packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.geo);
        packet.emit(hdr.powerlink);
    }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;

