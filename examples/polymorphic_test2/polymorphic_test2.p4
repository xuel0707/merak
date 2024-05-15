/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>



#ifdef UDEF_ASIC
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
#endif

#ifdef UDEF_ASIC
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

#endif 

#ifdef UDEF_PPK
const bit<9> PORT_BIT_MCAST = 254;
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
    packet_out_header_t packet_out;
    packet_in_header_t packet_in;
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
            default: accept;
        }
    }

    @name(".parse_geo")  state parse_geo{
        packet.extract(hdr.geo);
        transition select(hdr.geo.ht) { 
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


    /*****GEO PPK START******/
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
        standard_metadata.egress_spec = PORT_BIT_MCAST;
        standard_metadata.bit_mcast = bitcast;
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
            hdr.gbc.disa: exact;
            hdr.gbc.disb: exact;
        }
        size = 1024;
        default_action = geo_fwd2ONOS();
    }
     /********GEO PPK END************/


     /*******IPv4 7132 START*******/
    action ipv4_set_egress(bit<9> port) {
        standard_metadata.egress_port = port;
    }

    action ipv4_drop() {
        mark_to_drop(standard_metadata);
    }

    table ipv4_forward_table {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            ipv4_set_egress;
            ipv4_drop;
        }
        default_action = ipv4_drop();
        size = 1024;
    }
     /*******IPv4 7132 END*******/


 /*****START ADD  VLAN*****/
    action add_vlan(){
        hdr.vlan.setValid();
        //VID的高6bit存储输入端口号，是否需要改成0x1，是固定的，还可以从7132某个字段中读出？
        hdr.vlan.vid[11:6] = standard_metadata.ingress_port[5:0];
        hdr.vlan.etherType = hdr.ethernet.etherType;
    }

    action change_low_vid(){
         hdr.vlan.vid[5:0] = LOW_VID;
    } 
    action change_ethertype(){
        hdr.ethernet.etherType = 0x8100;
        
    }
    action not_tna_forward_card0() {
        standard_metadata.egress_port = 62;
    }

    /*****END ADD VLAN*****/

    /*****START DELETE VLAN*****/
    action del_vlan_change_ethernet() {
        hdr.ethernet.etherType = hdr.vlan.etherType;
    }
    action extract_vlan_port_forward(){
        standard_metadata.egress_port = (bit<9>) hdr.vlan.vid[7:0];
    }
    action del_vlan(){
        hdr.vlan.setInvalid();
    }
    /*****END DELETE VLAN*****/

    apply {

        //PPK 处理GEO
        if (hdr.gbc.isValid()){
            gbc_exact.apply();
        }
        //7132处理ipv4
        else if (hdr.ipv4.isValid()) {
            ipv4_forward_table.apply();
        } 

        //7132处理GEO包，实现加VLAN转发到PPK
        else if (hdr.ethernet.etherType == TYPE_GEO){
            add_vlan();
            change_low_vid();
            change_ethertype();
            not_tna_forward_card0();
        }
         //7132处理加VLAN的GEO包，实现删除VLAN转发到前面板
        else if(hdr.vlan.etherType == TYPE_GEO ){   
            del_vlan_change_ethernet();
            extract_vlan_port_forward();
            del_vlan();
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
     }
}



V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressImpl(), EgressImpl(), ComputeChecksumImpl(), DeparserImpl()) main;


