/*
 * Copyright 2019-present Open Networking Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<9> PORT_BIT_MCAST = 254;

const bit<16> TYPE_VLAN = 0x8100;
const bit<16> TYPE_IPV4 = 0x800;    
const bit<9>  GHC0_IN = 44;
const bit<9>  GHC1_IN = 176;
const bit<6>  LOW_VID = 0x3F;
const bit<16> TYPE_IPV6 = 0x86DD;   
const bit<16> TYPE_GEO = 0x8947;    
const bit<16> TYPE_MF = 0x27c0;    
const bit<16> TYPE_EPL = 0x88ab;
const bit<16> TYPE_NDN = 0x8624;

const bit<16> TYPE_TPID = 0x8100;
const bit<16> TYPE_IC = 0x88AB;   
header vlan_tag_h {
    bit<16>  vid;
    bit<16> etherType;
}

header ic_h {
    bit<1> saved;
    bit<7> type;
    bit<8> dstPoint;
    bit<8> srcPoint;
}

header vlan_t {
    bit<3>  typeID;
    bit<1>  cfi;
    bit<12>  vid;
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

header mf_guid_t{
    bit<32> mf_type;
	bit<32> src_guid;
    bit<32> dest_guid;
}

header ipv6_t {
    bit<4>      version;
    bit<8>      traffic_class;
    bit<20>     flow_label;
    bit<16>     payload_length;
    bit<8>      nextHdr;
    bit<8>      hopLimit;
    bit<128>    srcAddr;
    bit<128>    dstAddr;
}

const bit<4> TYPE_geo_beacon = 0x1;
const bit<4> TYPE_geo_gbc = 0x4;     
const bit<4> TYPE_geo_tsb = 0x5; 
const bit<9> PORT_ONOS =255;
const bit<9> CPU_PORT = 255;

header geo_t{
    bit<4>  version;
    bit<4>  nh_basic;
    bit<8>  reserved_basic;
    bit<8>  lt;
    bit<8>  rhl;
    bit<4> nh_common;
    bit<4> reserved_common_a;
    bit<4> ht;
    bit<4> hst;
    bit<8> tc;
    bit<8> flag;
    bit<16> pl;
    bit<8> mhl;
    bit<8> reserved_common_b;
}

header gbc_t{
    bit<16> sn;
    bit<16> reserved_gbc_a;
    bit<64> gnaddr;
    bit<32> tst;
    bit<32> lat;
    bit<32> longg;
    bit<1> pai;
    bit<15> s;
    bit<16> h;
    bit<32> geoAreaPosLat; //请求区域中心点的维度
    bit<32> geoAreaPosLon; //请求区域中心点的经度
    bit<16> disa;
    bit<16> disb;
    bit<16> angle;
    bit<16> reserved_gbc_b; 
}

header beacon_t{
    bit<64> gnaddr;
    bit<32> tst;
    bit<32> lat;
    bit<32> longg;
    bit<1> pai;
    bit<15> s;
    bit<16> h;
    //是否可以在header中使用结构体
}

header powerlink_t {
    bit<1>    saved;
    bit<7>    message_type;
    bit<8>    dst_node;
    bit<8>    src_node;
}

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

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct headers {
    ethernet_t ethernet;
    vlan_t     vlan;
    ipv4_t     ipv4;
    geo_t       geo;
    gbc_t       gbc;
    beacon_t    beacon;
    ipv6_t       ipv6;
    mf_guid_t       mf;
    powerlink_t powerlink;
    packet_out_header_t packet_out;
    packet_in_header_t packet_in;
    vlan_tag_h vlan_tag;
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
            0x8947: parse_geo;
            TYPE_VLAN: parse_vlan;
            TYPE_IPV4: parse_ipv4;
            0x86dd : parse_ipv6;
            0x27c0: parse_mf;
            0x88ab: parse_epl;
            default: accept;
        }
    }

    @name(".parse_geo")  state parse_geo{
        packet.extract(hdr.geo);
        transition select(hdr.geo.ht) { //要根据ht的大小来判断选取的字段
            TYPE_geo_beacon: parse_beacon; //0x01
            TYPE_geo_gbc: parse_gbc;       //0x04
            TYPE_geo_tsb: parse_tsb;  //0x05  
            default: accept;
        }
    }

    @name(".parse_beacon") state parse_beacon{
        packet.extract(hdr.beacon);
        transition accept;
    }

    @name(".parse_gbc") state parse_gbc{
        packet.extract(hdr.gbc);
        transition accept;
    }

    @name(".parse_tsb") state parse_tsb{
        //packet.extract(hdr.tsb);
        transition accept;
    }
    @name(".parse_ipv6") state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition accept;
    }

    @name(".parse_mf") state parse_mf{
        packet.extract(hdr.mf);
		transition accept;
    }

    @name(".parse_epl") state parse_epl {
        packet.extract(hdr.powerlink);
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
    action _drop() {
        mark_to_drop(standard_metadata);
    }

    action geo_unicast(bit<9> port) {
        standard_metadata.egress_spec = port;
    }
    action l3_forward(bit<9> port) {
        standard_metadata.egress_port = port;
    }
    action geo_fwd2ONOS() {
       standard_metadata.egress_spec = PORT_ONOS; //clone3(CloneType.I2E, CPU_CLONE_SESSION_ID, standard_metadata);
    }

    action geo_multicast(bit <32> bitcast) {
      //  standard_metadata.mcast_grp = grpid;
        standard_metadata.egress_spec = PORT_BIT_MCAST;
        standard_metadata.bit_mcast = bitcast;
    }//用于组播的动作函数
    // ipv6 action 
    action ipv6_forward(bit<9> port) {
        l3_forward(port);
        hdr.ipv6.hopLimit = hdr.ipv6.hopLimit - 1;
    }

    // mf action
    action dest_guid_forward(bit<9> port) {
        standard_metadata.egress_port = port;
    }
    // powerlink action
    action epl_multicast(bit<32> mcast_grp) {
        standard_metadata.egress_spec = PORT_BIT_MCAST;
        standard_metadata.bit_mcast = mcast_grp;
        //meta.is_multicast = true;
    }
    action epl_set_egress_port(bit<9> port_num) {
        standard_metadata.egress_port = port_num;
    }

    action set_egress_port(bit<9> port_num) {
        standard_metadata.egress_port = port_num;
    }

    table gbc_exact {
        actions = {
            geo_multicast;//这是新加的动作
            geo_unicast;
            geo_fwd2ONOS;
        }
        key = {
            hdr.gbc.geoAreaPosLat: exact;
            hdr.gbc.geoAreaPosLon: exact;
            hdr.gbc.disa: exact;
            hdr.gbc.disb: exact;
        }
        size = 1024;
        default_action = geo_fwd2ONOS();
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
       // default_action = send_to_cpu();
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
    action action1() {
        standard_metadata.egress_port = 0x1;
        hdr.vlan_tag.vid = 0x2;
    }

    table ic_exact {
        key = {hdr.ethernet.etherType:exact;
               hdr.vlan_tag.etherType:exact;}
        actions = {
            action1; 
            NoAction;
        }
        const default_action = NoAction;
    }
     
    apply {
        if (hdr.gbc.isValid()){
            gbc_exact.apply();
        }
        else if (hdr.ipv6.isValid()) {
            ipv6_exact.apply();
        }
        else if (hdr.mf.isValid()) {
            dest_guid_exact.apply();
        }
        else if (hdr.ipv4.isValid()) {
            ipv4_forward_table.apply();
        } else if (hdr.ic.isValid()) {
            ic_exact.apply();
        }
        else{
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
	packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.geo);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.mf);
        packet.emit(hdr.powerlink);
        packet.emit(hdr.vlan_tag);
        packet.emit(hdr.ic);
    }
}



V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;


