#include <core.p4>
#define V1MODEL_VERSION 20180101
#include <v1model.p4>

typedef bit<9> port_num_t;
typedef bit<48> mac_addr_t;
typedef bit<16> mcast_group_id_t;
typedef bit<32> ipv4_addr_t;
typedef bit<128> ipv6_addr_t;
typedef bit<16> l4_port_t;
const bit<16> ETHERTYPE_IPV4 = 0x800;
const bit<16> ETHERTYPE_IPV6 = 0x86dd;
const bit<8> IP_PROTO_ICMP = 1;
const bit<8> IP_PROTO_TCP = 6;
const bit<8> IP_PROTO_UDP = 17;
const bit<8> IP_PROTO_SRV6 = 43;
const bit<8> IP_PROTO_ICMPV6 = 58;
const mac_addr_t IPV6_MCAST_01 = 0x333300000001;
const bit<8> ICMP6_TYPE_NS = 135;
const bit<8> ICMP6_TYPE_NA = 136;
const bit<8> NDP_OPT_TARGET_LL_ADDR = 2;
const bit<32> NDP_FLAG_ROUTER = 0x80000000;
const bit<32> NDP_FLAG_SOLICITED = 0x40000000;
const bit<32> NDP_FLAG_OVERRIDE = 0x20000000;
header ethernet_t {
    mac_addr_t dst_addr;
    mac_addr_t src_addr;
    bit<16>    ether_type;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<6>  dscp;
    bit<2>  ecn;
    bit<16> total_len;
    bit<16> identification;
    bit<3>  flags;
    bit<13> frag_offset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdr_checksum;
    bit<32> src_addr;
    bit<32> dst_addr;
}

header ipv6_t {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_len;
    bit<8>   next_hdr;
    bit<8>   hop_limit;
    bit<128> src_addr;
    bit<128> dst_addr;
}

header srv6h_t {
    bit<8>  next_hdr;
    bit<8>  hdr_ext_len;
    bit<8>  routing_type;
    bit<8>  segment_left;
    bit<8>  last_entry;
    bit<8>  flags;
    bit<16> tag;
}

header srv6_list_t {
    bit<128> segment_id;
}

header tcp_t {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4>  data_offset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_t {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> len;
    bit<16> checksum;
}

header icmp_t {
    bit<8>  type;
    bit<8>  icmp_code;
    bit<16> checksum;
    bit<16> identifier;
    bit<16> sequence_number;
    bit<64> timestamp;
}

header icmpv6_t {
    bit<8>  type;
    bit<8>  code;
    bit<16> checksum;
}

header ndp_t {
    bit<32>     flags;
    ipv6_addr_t target_ipv6_addr;
    bit<8>      type;
    bit<8>      length;
    bit<48>     target_mac_addr;
}

@controller_header("packet_in") header cpu_in_header_t {
    port_num_t ingress_port;
    bit<7>     _pad;
}

@controller_header("packet_out") header cpu_out_header_t {
    port_num_t egress_port;
    bit<7>     _pad;
}

struct parsed_headers_t {
    cpu_out_header_t cpu_out;
    cpu_in_header_t  cpu_in;
    ethernet_t       ethernet;
    ipv4_t           ipv4;
    ipv6_t           ipv6;
    srv6h_t          srv6h;
    srv6_list_t[4]   srv6_list;
    tcp_t            tcp;
    udp_t            udp;
    icmp_t           icmp;
    icmpv6_t         icmpv6;
    ndp_t            ndp;
}

struct local_metadata_t {
    l4_port_t   l4_src_port;
    l4_port_t   l4_dst_port;
    bool        is_multicast;
    ipv6_addr_t next_srv6_sid;
    bit<8>      ip_proto;
    bit<8>      icmp_type;
}

parser ParserImpl(packet_in packet, out parsed_headers_t hdr, inout local_metadata_t local_metadata, inout standard_metadata_t standard_metadata) {
    state start {
        transition select(standard_metadata.ingress_port) {
            255: parse_packet_out;
            default: parse_ethernet;
        }
    }
    state parse_packet_out {
        packet.extract(hdr.cpu_out);
        transition parse_ethernet;
    }
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4: parse_ipv4;
            ETHERTYPE_IPV6: parse_ipv6;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        local_metadata.ip_proto = hdr.ipv4.protocol;
        transition select(hdr.ipv4.protocol) {
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            IP_PROTO_ICMP: parse_icmp;
            default: accept;
        }
    }
    state parse_ipv6 {
        packet.extract(hdr.ipv6);
        local_metadata.ip_proto = hdr.ipv6.next_hdr;
        transition select(hdr.ipv6.next_hdr) {
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            IP_PROTO_ICMPV6: parse_icmpv6;
            IP_PROTO_SRV6: parse_srv6;
            default: accept;
        }
    }
    state parse_tcp {
        packet.extract(hdr.tcp);
        local_metadata.l4_src_port = hdr.tcp.src_port;
        local_metadata.l4_dst_port = hdr.tcp.dst_port;
        transition accept;
    }
    state parse_udp {
        packet.extract(hdr.udp);
        local_metadata.l4_src_port = hdr.udp.src_port;
        local_metadata.l4_dst_port = hdr.udp.dst_port;
        transition accept;
    }
    state parse_icmp {
        packet.extract(hdr.icmp);
        local_metadata.icmp_type = hdr.icmp.type;
        transition accept;
    }
    state parse_icmpv6 {
        packet.extract(hdr.icmpv6);
        local_metadata.icmp_type = hdr.icmpv6.type;
        transition select(hdr.icmpv6.type) {
            ICMP6_TYPE_NS: parse_ndp;
            ICMP6_TYPE_NA: parse_ndp;
            default: accept;
        }
    }
    state parse_ndp {
        packet.extract(hdr.ndp);
        transition accept;
    }
    state parse_srv6 {
        packet.extract(hdr.srv6h);
        transition parse_srv6_list;
    }
    state parse_srv6_list {
        packet.extract(hdr.srv6_list.next);
        bool next_segment = (bit<32>)hdr.srv6h.segment_left - 1 == (bit<32>)hdr.srv6_list.lastIndex;
        transition select(next_segment) {
            true: mark_current_srv6;
            default: check_last_srv6;
        }
    }
    state mark_current_srv6 {
        local_metadata.next_srv6_sid = hdr.srv6_list.last.segment_id;
        transition check_last_srv6;
    }
    state check_last_srv6 {
        bool last_segment = (bit<32>)hdr.srv6h.last_entry == (bit<32>)hdr.srv6_list.lastIndex;
        transition select(last_segment) {
            true: parse_srv6_next_hdr;
            false: parse_srv6_list;
        }
    }
    state parse_srv6_next_hdr {
        transition select(hdr.srv6h.next_hdr) {
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            IP_PROTO_ICMPV6: parse_icmpv6;
            default: accept;
        }
    }
}

control VerifyChecksumImpl(inout parsed_headers_t hdr, inout local_metadata_t meta) {
    apply {
    }
}

control IngressPipeImpl(inout parsed_headers_t hdr, inout local_metadata_t local_metadata, inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }
    action set_egress_port(port_num_t port_num) {
        standard_metadata.egress_spec = port_num;
    }
    table l2_exact_table {
        key = {
            hdr.ethernet.dst_addr: exact;
        }
        actions = {
            set_egress_port;
            @defaultonly drop;
        }
        const default_action = drop;
        @name("l2_exact_table_counter") counters = direct_counter(CounterType.packets_and_bytes);
    }
    action set_multicast_group(mcast_group_id_t gid) {
        standard_metadata.mcast_grp = gid;
        local_metadata.is_multicast = true;
    }
    table l2_ternary_table {
        key = {
            hdr.ethernet.dst_addr: ternary;
        }
        actions = {
            set_multicast_group;
            @defaultonly drop;
        }
        const default_action = drop;
        @name("l2_ternary_table_counter") counters = direct_counter(CounterType.packets_and_bytes);
    }
    action send_to_cpu() {
        standard_metadata.egress_spec = 255;
    }
    action clone_to_cpu() {
        clone3(CloneType.I2E, 99, { standard_metadata.ingress_port });
    }
    action udf_rule_forward(bit<8> udfId, bit<128> matchData, bit<128> matchMask) {
    }
    action udf_rule_drop(bit<8> udfId, bit<128> matchData, bit<128> matchMask) {
    }
    action udf_rule_redirect(bit<8> udfId, bit<128> matchData, bit<128> matchMask, port_num_t port) {
    }
    action udf_rule_redirect_modify_smac(bit<8> udfId, bit<128> matchData, bit<128> matchMask, port_num_t port, mac_addr_t mac) {
    }
    action udf_rule_redirect_modify_dmac(bit<8> udfId, bit<128> matchData, bit<128> matchMask, port_num_t port, mac_addr_t mac) {
    }
    action udf_rule_mirror(bit<8> udfId, bit<128> matchData, bit<128> matchMask, port_num_t port) {
    }
    action udf_rule_set_dscp(bit<8> udfId, bit<128> matchData, bit<128> matchMask, bit<3> dscp) {
    }
    table udf_rule_table {
        key = {
            standard_metadata.ingress_port: exact;
            local_metadata.ip_proto       : exact;
        }
        actions = {
            udf_rule_forward;
            udf_rule_drop;
            udf_rule_redirect;
            udf_rule_redirect_modify_smac;
            udf_rule_redirect_modify_dmac;
            udf_rule_mirror;
            udf_rule_set_dscp;
        }
    }
    table acl_table {
        key = {
            standard_metadata.ingress_port: ternary;
            hdr.ethernet.dst_addr         : ternary;
            hdr.ethernet.src_addr         : ternary;
            hdr.ethernet.ether_type       : ternary;
            local_metadata.ip_proto       : ternary;
            local_metadata.icmp_type      : ternary;
            local_metadata.l4_src_port    : ternary;
            local_metadata.l4_dst_port    : ternary;
        }
        actions = {
            send_to_cpu;
            clone_to_cpu;
            drop;
        }
        @name("acl_table_counter") counters = direct_counter(CounterType.packets_and_bytes);
    }
    apply {
        if (hdr.cpu_out.isValid()) {
        }
        bool do_l3_l2 = true;
        if (hdr.icmpv6.isValid() && hdr.icmpv6.type == ICMP6_TYPE_NS) {
        }
        if (do_l3_l2) {
            if (!l2_exact_table.apply().hit) {
                l2_ternary_table.apply();
            }
        }
        acl_table.apply();
        udf_rule_table.apply();
    }
}

control EgressPipeImpl(inout parsed_headers_t hdr, inout local_metadata_t local_metadata, inout standard_metadata_t standard_metadata) {
    apply {
        if (standard_metadata.egress_port == 255) {
        }
        if (local_metadata.is_multicast == true && standard_metadata.ingress_port == standard_metadata.egress_port) {
            mark_to_drop(standard_metadata);
        }
    }
}

control ComputeChecksumImpl(inout parsed_headers_t hdr, inout local_metadata_t local_metadata) {
    apply {
        update_checksum(hdr.ndp.isValid(), { hdr.ipv6.src_addr, hdr.ipv6.dst_addr, hdr.ipv6.payload_len, 8w0, hdr.ipv6.next_hdr, hdr.icmpv6.type, hdr.icmpv6.code, hdr.ndp.flags, hdr.ndp.target_ipv6_addr, hdr.ndp.type, hdr.ndp.length, hdr.ndp.target_mac_addr }, hdr.icmpv6.checksum, HashAlgorithm.csum16);
    }
}

control DeparserImpl(packet_out packet, in parsed_headers_t hdr) {
    apply {
        packet.emit(hdr.cpu_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.srv6h);
        packet.emit(hdr.srv6_list);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
        packet.emit(hdr.icmp);
        packet.emit(hdr.icmpv6);
        packet.emit(hdr.ndp);
    }
}

V1Switch(ParserImpl(), VerifyChecksumImpl(), IngressPipeImpl(), EgressPipeImpl(), ComputeChecksumImpl(), DeparserImpl()) main;

