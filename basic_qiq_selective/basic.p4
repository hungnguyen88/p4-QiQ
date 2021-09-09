/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_VLAN = 0x8100;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header vlan_t {
   bit<3>   PRI;
   bit<1>   CFI;
   bit<12>  VID;
   bit<16>  etherType;
}

struct metadata {
    /* empty */
}

struct headers {
    ethernet_t  ethernet;
    vlan_t  vlan_qiq;
    vlan_t  vlan;
    ipv4_t  ipv4;
}


/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
	packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
	    	TYPE_VLAN: parse_vlan;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_vlan {
        packet.extract(hdr.vlan);
        transition select(hdr.vlan.etherType) {
	    TYPE_VLAN: parse_vlan_qiq;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_vlan_qiq {
	hdr.vlan_qiq = hdr.vlan;
        packet.extract(hdr.vlan);
        transition select(hdr.vlan.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }
    
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    bit<1> vlan_access_mode = 0;

    action vlan_access(egressSpec_t port, bit<3> PRI, bit<1> CFI, bit<12>  VID){
        standard_metadata.egress_spec = port;
        hdr.vlan.setValid();
        hdr.vlan.PRI = PRI;
	    hdr.vlan.CFI = CFI;
	    hdr.vlan.VID = VID;
	    hdr.vlan.etherType = hdr.ethernet.etherType;

	    hdr.ethernet.etherType = TYPE_VLAN;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        vlan_access_mode = 1;
         
    }

    action vlan_release(egressSpec_t port) {
		standard_metadata.egress_spec = port;
		hdr.ethernet.etherType = hdr.vlan.etherType;
		hdr.ipv4.ttl = hdr.ipv4.ttl - 1;		
		hdr.vlan.setInvalid();
    }

    action vlan_forward(egressSpec_t port) {
          standard_metadata.egress_spec = port;
          hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    bit<1> qiq_access_mode = 0;
    action standard_qiq_access(egressSpec_t port, bit<3> PRI, bit<1> CFI, bit<12>  VID) {
        standard_metadata.egress_spec = port;
        hdr.vlan_qiq.setValid();
        hdr.vlan_qiq.PRI = PRI;
        hdr.vlan_qiq.CFI = CFI;
        hdr.vlan_qiq.VID = VID;
        hdr.vlan_qiq.etherType = TYPE_VLAN;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        qiq_access_mode = 1;
    }

    action selective1_qiq_access(egressSpec_t port, bit<3> PRI, bit<1> CFI, bit<12>  VID) {
        standard_metadata.egress_spec = port;
        hdr.vlan_qiq.setValid();
        hdr.vlan_qiq.PRI = PRI;
        hdr.vlan_qiq.CFI = CFI;
        hdr.vlan_qiq.VID = VID;
        hdr.vlan_qiq.etherType = TYPE_VLAN;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        qiq_access_mode = 1;
    }

    action selective2_qiq_access(egressSpec_t port, bit<3> PRI, bit<1> CFI, bit<12>  VID) {
        standard_metadata.egress_spec = port;
        hdr.vlan_qiq.setValid();
        hdr.vlan_qiq.PRI = PRI;
        hdr.vlan_qiq.CFI = CFI;
        hdr.vlan_qiq.VID = VID;
        hdr.vlan_qiq.etherType = TYPE_VLAN;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        qiq_access_mode = 1;
    }

    action selective1_qiq_release(egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;        
        hdr.vlan_qiq.setInvalid();
    }

    action selective1_qiq_forward(egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action selective2_qiq_release(egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;        
        hdr.vlan_qiq.setInvalid();
    }

    action selective2_qiq_forward(egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action standard_qiq_release(egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;        
        hdr.vlan_qiq.setInvalid();
    }

    action standard_qiq_forward(egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

   table vlan_access_exact {
        key = {
            hdr.ethernet.dstAddr: exact;
            standard_metadata.ingress_port: exact;
        }
        actions = {
            vlan_access;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }
    
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

   table vlan_exact {
        key = {
	        hdr.ethernet.dstAddr: exact;
            hdr.vlan.VID: exact;
        }
        actions = {
            vlan_release;
            vlan_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    table standard_qiq_access_exact {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
            standard_qiq_access;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }

    table selective1_qiq_access_exact {
        key = {
            hdr.ethernet.srcAddr: exact;
        }
        actions = {
            selective1_qiq_access;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }

    table selective2_qiq_access_exact {
        key = {
            hdr.vlan.VID: exact;
        }
        actions = {
            selective2_qiq_access;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }

    table standard_qiq_exact {
        key = {
            hdr.vlan_qiq.VID: exact;
        }
        actions = {
            standard_qiq_release;
            standard_qiq_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    table selective1_qiq_exact {
        key = {
            hdr.vlan_qiq.VID: exact;
        }
        actions = {
            selective1_qiq_release;
            selective1_qiq_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }

    table selective2_qiq_exact {
        key = {
            hdr.vlan_qiq.VID: exact;
        }
        actions = {
            selective2_qiq_release;
            selective2_qiq_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }

    apply {
    if (!hdr.vlan.isValid()){
            vlan_access_exact.apply();
    }
	
    if (hdr.ipv4.isValid()&&!hdr.vlan.isValid()&&(vlan_access_mode==0)) {
            ipv4_lpm.apply();
        }
    
    if (hdr.vlan.isValid()&&!hdr.vlan_qiq.isValid()&&(vlan_access_mode==0)) {
            vlan_exact.apply();    
            standard_qiq_access_exact.apply();
            selective1_qiq_access_exact.apply();
            selective2_qiq_access_exact.apply();       
        }

    if (hdr.vlan_qiq.isValid()&&(vlan_access_mode==0)&&(qiq_access_mode==0)) {
            
            standard_qiq_exact.apply();   
            selective1_qiq_exact.apply();
            selective2_qiq_exact.apply();    
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.vlan_qiq);
        packet.emit(hdr.vlan);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
