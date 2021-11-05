/* -*- P4_16 -*- */

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_h   ethernet;
    vlan_tag_h[3]   vlan_tag;
    ipv4_h       ipv4;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
}

    /***********************  P A R S E R  **************************/
parser IngressParser(packet_in        pkt,
    /* User */
    out my_ingress_headers_t          hdr,
    out my_ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

#ifdef PARSER_OPT
    @critical
#endif
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.TPID:  parse_vlan_tag;
            ether_type_t.IPV4:  parse_ipv4;
            default: accept;
        }
    }

    state parse_vlan_tag {
        transition parse_vlan_tag_0;
    }

    state parse_vlan_tag_0 {
        pkt.extract(hdr.vlan_tag[0]);
        transition select(hdr.vlan_tag[0].ether_type) {
            ether_type_t.TPID :  parse_vlan_tag_1;
            ether_type_t.IPV4 :  parse_ipv4;
            default: accept;
        }
    }
    state parse_vlan_tag_1 {
        pkt.extract(hdr.vlan_tag[1]);
        transition select(hdr.vlan_tag[1].ether_type) {
            ether_type_t.TPID :  parse_vlan_tag_2;
            ether_type_t.IPV4 :  parse_ipv4;
            default: accept;
        }
    }
    state parse_vlan_tag_2 {
        pkt.extract(hdr.vlan_tag[2]);
        transition select(hdr.vlan_tag[2].ether_type) {
            ether_type_t.TPID :  too_many_vlan_tags;
            ether_type_t.IPV4 :  parse_ipv4;
            default: accept;
        }
    }
    state too_many_vlan_tags {
        transition select(hdr.vlan_tag[2].ether_type) {
            /* No transition -- drop packet in the ingress parser */
        }
    }

    
    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

control Ingress(
    /* User */
    inout my_ingress_headers_t                       hdr,
    inout my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md)
{
#if defined(USE_ALPM_NEW) && (ALPM_NAME)
    Alpm(number_partitions=ALPM_PARTITIONS) lpm_alpm;
#endif
    
    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
#ifdef BYPASS_EGRESS
        ig_tm_md.bypass_egress = 1;
#endif
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    bit<1> vlan_access_mode = 0;
    action vlan_access(PortId_t port, bit<3> PRI, bit<1> CFI, bit<12>  VID){
        ig_tm_md.ucast_egress_port = port;
        hdr.vlan_tag[0].setValid();
        hdr.vlan_tag[0].pri = PRI;
	hdr.vlan_tag[0].dei = CFI;
	hdr.vlan_tag[0].vid = VID;
	hdr.vlan_tag[0].ether_type = hdr.ethernet.ether_type;

	hdr.ethernet.ether_type = ether_type_t.TPID;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        vlan_access_mode = 1;
         
    }

    action vlan_release(PortId_t port) {
		ig_tm_md.ucast_egress_port = port;
		hdr.ethernet.ether_type = hdr.vlan_tag[0].ether_type;	
		hdr.vlan_tag[0].setInvalid();
    }

    action vlan_forward(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }


    bit<1> qiq_access_mode = 0;
    action standard_qiq_access(PortId_t port, bit<3> PRI, bit<1> CFI, bit<12>  VID) {
        ig_tm_md.ucast_egress_port = port;

        hdr.vlan_tag[1].setValid();
        hdr.vlan_tag[1].pri = hdr.vlan_tag[0].pri;
        hdr.vlan_tag[1].dei = hdr.vlan_tag[0].dei;
        hdr.vlan_tag[1].vid = hdr.vlan_tag[0].vid;
        hdr.vlan_tag[1].ether_type = hdr.vlan_tag[0].ether_type;
 
        hdr.vlan_tag[0].pri = PRI;
        hdr.vlan_tag[0].dei = CFI;
        hdr.vlan_tag[0].vid = VID;
        hdr.vlan_tag[0].ether_type = ether_type_t.TPID;
        qiq_access_mode = 1;
    }

    action standard_qiq_release(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;

        hdr.vlan_tag[0].pri = hdr.vlan_tag[1].pri;
        hdr.vlan_tag[0].dei = hdr.vlan_tag[1].dei;
        hdr.vlan_tag[0].vid = hdr.vlan_tag[1].vid;
        hdr.vlan_tag[0].ether_type = hdr.vlan_tag[1].ether_type;

        hdr.vlan_tag[1].setInvalid();
    }

    action standard_qiq_forward(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }


    table vlan_access_exact {
        key = {
            hdr.ethernet.dst_addr: exact;
            ig_intr_md.ingress_port: exact;
        }
        actions = {
            vlan_access;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }

    table vlan_exact {
        key = {
	        hdr.ethernet.dst_addr: exact;
                hdr.vlan_tag[0].vid: exact;
        }
        actions = {
            vlan_release;
            vlan_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }


    table std_qiq_access_exact {
        key = {
            ig_intr_md.ingress_port: exact;
        }
        actions = {
            standard_qiq_access;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }

    table std_qiq_exact {
        key = {
            hdr.vlan_tag[0].vid: exact;
        }
        actions = {
            standard_qiq_release;
            standard_qiq_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }


    table ipv4_host {
        key = { hdr.ipv4.dst_addr : exact; }
        actions = {
            send; drop;
#ifdef ONE_STAGE
            @defaultonly NoAction;
#endif /* ONE_STAGE */
        }

#ifdef ONE_STAGE
        const default_action = NoAction();
#endif /* ONE_STAGE */

        size = IPV4_HOST_SIZE;
    }

#if defined(USE_ALPM) && !defined(USE_ALPM_NEW)
    @alpm(1)
    @alpm_partitions(ALPM_PARTITIONS)
#endif
    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = { send; drop; }

#if defined(USE_ALPM_NEW)
#if defined(ALPM_NAME)        
        alpm = lpm_alpm;
#else        
        alpm = Alpm(number_partitions=ALPM_PARTITIONS);
#endif
#endif
        default_action = send(64);
        size           = IPV4_LPM_SIZE;
    }

    apply {
        if (!hdr.vlan_tag[0].isValid()){
            vlan_access_exact.apply();
        }
        if (hdr.ipv4.isValid()&&!hdr.vlan_tag[0].isValid()&&(vlan_access_mode==0)) {
            if (ipv4_host.apply().miss) {
                ipv4_lpm.apply();
            }
        }
        if (hdr.vlan_tag[0].isValid()&&!hdr.vlan_tag[1].isValid()&&(vlan_access_mode==0)) {
            vlan_exact.apply();
            std_qiq_access_exact.apply();      
        }
        if (hdr.vlan_tag[1].isValid()&&(vlan_access_mode==0)&&(qiq_access_mode==0)) {           
            std_qiq_exact.apply();   
        }
    }
}

    /*********************  D E P A R S E R  ************************/

control IngressDeparser(packet_out pkt,
    /* User */
    inout my_ingress_headers_t                       hdr,
    in    my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md)
{
    apply {
        pkt.emit(hdr);
    }
}

