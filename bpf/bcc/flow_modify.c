#define KBUILD_MODNAME "foo"
#include <uapi/linux/bpf.h>
#include <linux/in.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/if_vlan.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <bcc/proto.h>

// modify packet's TCP payload by swapping two 16-bit aligned
// values to preserve TCP checksum. 

struct flowrec {
  uint32_t saddr, daddr;
  uint16_t sport, dport;
  int udp, active;
  uint32_t cnt, idx, modded;
};

// if no flowspecs are given, flownum will be 0 and we can't have that
BPF_ARRAY(flowspecs, struct flowrec, (FLOWNUM > 0 ? FLOWNUM : 1));

// get IP protocol
static inline struct iphdr* parse_ipv4(void *data, u64 nh_off, void *data_end) {
    struct iphdr *iph = data + nh_off;

    if ((void*)&iph[1] > data_end)
        return 0;
    return iph;
}

// swap u16-s at offset 1 and 2, but do not go outside the payload end
static inline int swapu16(uint16_t *start, void *data_end, int off1, int off2) {
  uint16_t poff1, poff2;

  // check first octet
  if (((void*)&start[off1] > data_end) || ((void*)&start[off2] > data_end)) 
    return 0;

  // check second octet
  if (((void*)&start[off1+1] > data_end) || ((void*)&start[off2 + 1] > data_end))
    return 0;
  
  poff1 = start[off1];
  poff2 = start[off2];

  start[off2] = poff1;
  start[off1] = poff2;

  return 1;
}

// test packet headers against TCP flow record
static inline int testTcpFlow(struct iphdr *iph, struct tcphdr *tcph, struct flowrec *flow) {
  if (flow != NULL) {
    // make sure it is an active TCP flow record
    if ((flow->active == 0) || (flow->udp != 0))
      return 0;

    if ((flow->saddr != 0) && (iph->saddr != flow->saddr))
      return 0;

    if ((flow->daddr != 0) && (iph->daddr != flow->daddr))
      return 0;

    if ((flow->sport != 0) && (tcph->source != flow->sport))
      return 0;

    if ((flow->dport != 0) && (tcph->dest != flow->dport))
      return 0;

    return 1;
  }
  return 0;
}

// test packet headers against UDP flow record
static inline int testUdpFlow(struct iphdr *iph, struct udphdr *udph, struct flowrec *flow) {
  if (flow != NULL) {
    // make sure it is an active UDP flow record
    if ((flow->active == 0) || (flow->udp != 1))
      return 0;

    if ((flow->saddr != 0) && (iph->saddr != flow->saddr))
      return 0;

    if ((flow->daddr != 0) && (iph->daddr != flow->daddr))
      return 0;

    if ((flow->sport != 0) && (udph->source != flow->sport))
      return 0;

    if ((flow->dport != 0) && (udph->dest != flow->dport))
      return 0;

    return 1;
  }
  return 0;
}

// get TCP header
static inline struct tcphdr* parse_tcp(void *data, u64 nh_off, void *data_end) {
  struct tcphdr *tcph = data + nh_off;

  if ((void*)&tcph[1] > data_end)
    return 0;

  return tcph;
}

// get UDP header
static inline struct udphdr* parse_udp(void *data, u64 nh_off, void *data_end) {
  struct udphdr *udph = data + nh_off;

  if ((void*)&udph[1] > data_end)
    return 0;

  return udph;
}

// get payload UDP or TCP
static inline uint16_t *parse_pld(void *data, u64 nh_off, void *data_end) {
  uint16_t *pld = data + nh_off;

  if ((void*)&pld[1] > data_end)
    return 0;

  return pld;
}


// note that context type is passed in as a parameter by BCC
int xdp_flow_mod_prog(struct CTXTYPE *ctx) {

    void* data_end = (void*)(long)ctx->data_end;
    void* data = (void*)(long)ctx->data;

    struct ethhdr *eth = data;

    // always pass packets 
    int rc = RETCODE;
    uint16_t h_proto;
    uint64_t nh_off = 0;
    struct iphdr *ip_hdr;
    struct tcphdr *tcp_hdr;
    struct udphdr *udp_hdr;
    uint16_t *pld;

    nh_off = sizeof(*eth);

    if (data + nh_off  > data_end)
        return rc;

    h_proto = eth->h_proto;

    if (h_proto == htons(ETH_P_8021Q) || h_proto == htons(ETH_P_8021AD)) {
        struct vlan_hdr *vhdr;

        vhdr = data + nh_off;
        nh_off += sizeof(struct vlan_hdr);
        if (data + nh_off > data_end)
            return rc;
    }
    if (h_proto == htons(ETH_P_8021Q) || h_proto == htons(ETH_P_8021AD)) {
        struct vlan_hdr *vhdr;

        vhdr = data + nh_off;
        nh_off += sizeof(struct vlan_hdr);
        if (data + nh_off > data_end)
            return rc;
    }

    // add IPv6 code as needed
    if (h_proto == htons(ETH_P_IP)) {
      ip_hdr = parse_ipv4(data, nh_off, data_end);
    } else
        ip_hdr = 0;

    if (ip_hdr != 0) {
      if (ip_hdr->protocol == IPPROTO_TCP) {
	nh_off += ip_hdr->ihl << 2;
	tcp_hdr = parse_tcp(data, nh_off, data_end);
	if (tcp_hdr != 0) {
	  nh_off += tcp_hdr->doff << 2;
	  pld = parse_pld(data, nh_off, data_end);
	  // note that syn packets may not contain any payload
	  if (pld != 0) {
	    int idx = 0, match = 0;
	    struct flowrec *rec;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL) {
	      if (rec->active == 0) {
		// match all TCP packets - no flowspecs in table
		match = 1;
	      } else 
		match = testTcpFlow(ip_hdr, tcp_hdr, rec);
	    }
	    if (match != 0)
	      goto matchtcp;
	    
	    idx = 1;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testTcpFlow(ip_hdr, tcp_hdr, rec);
	    if (match != 0)
	      goto matchtcp;
	    
	    idx = 2;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testTcpFlow(ip_hdr, tcp_hdr, rec);
	    if (match != 0)
	      goto matchtcp;
	    
	    idx = 3;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testTcpFlow(ip_hdr, tcp_hdr, rec);
	    if (match != 0)
	      goto matchtcp;
	    
	    idx = 4;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testTcpFlow(ip_hdr, tcp_hdr, rec);

	  matchtcp:
	    if (match > 0) {
	      lock_xadd(&rec->cnt, 1);
	      if (rec->cnt == PKTIDX) {
		if (REALLYMODIFY > 0) {
		  int swapres = swapu16(pld, data_end, SWAP1, SWAP2);
		  if (swapres == 1)
		    lock_xadd(&rec->modded, 1);
		}
		rec->cnt = 0;
	      }
	    }
	  } 
	}
      }

      if (ip_hdr->protocol == IPPROTO_UDP) {
	nh_off += ip_hdr->ihl << 2;
	udp_hdr = parse_udp(data, nh_off, data_end);
	if (udp_hdr != 0) {
	  nh_off += 16;
	  pld = parse_pld(data, nh_off, data_end);
	  if (pld != 0) {
	    int idx = 0, match = 0;
	    struct flowrec *rec;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testUdpFlow(ip_hdr, udp_hdr, rec);
	    if (match != 0)
	      goto matchudp;
	    
	    idx = 1;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testUdpFlow(ip_hdr, udp_hdr, rec);
	    if (match != 0)
	      goto matchudp;
	    
	    idx = 2;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testUdpFlow(ip_hdr, udp_hdr, rec);
	    if (match != 0)
	      goto matchudp;
	    
	    idx = 3;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testUdpFlow(ip_hdr, udp_hdr, rec);
	    if (match != 0)
	      goto matchudp;
	    
	    idx = 4;
	    rec = flowspecs.lookup(&idx);
	    if (rec != NULL)
	      match = testUdpFlow(ip_hdr, udp_hdr, rec);

	  matchudp:
	    if (match > 0) {
	      if (rec->cnt == PKTIDX) {
		lock_xadd(&rec->cnt, 1);
		if (REALLYMODIFY > 0) {
		  int swapres = swapu16(pld, data_end, SWAP1, SWAP2);
		  if (swapres == 1)
		    lock_xadd(&rec->modded, 1);
		}
		rec->cnt = 0;
	      }
	    }
	  }
	}
      }
    }

    return rc;
}
