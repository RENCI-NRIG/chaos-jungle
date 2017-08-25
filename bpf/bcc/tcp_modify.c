#define KBUILD_MODNAME "foo"
#include <uapi/linux/bpf.h>
#include <linux/in.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/if_vlan.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <bcc/proto.h>


// modify packet's TCP payload by swapping two 16-bit aligned
// values to preserve TCP checksum. 

BPF_ARRAY(flowcnt, uint32_t, 3);

// get IP protocol
static inline struct iphdr* parse_ipv4(void *data, u64 nh_off, void *data_end) {
    struct iphdr *iph = data + nh_off;

    if ((void*)&iph[1] > data_end)
        return 0;
    return iph;
}

// get IPv6 protocol
/*
static inline int parse_ipv6(void *data, u64 nh_off, void *data_end) {
    struct ipv6hdr *ip6h = data + nh_off;

    if ((void*)&ip6h[1] > data_end)
        return 0;
    return ip6h->nexthdr;
}
*/

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


// get TCP SYN flag value. BPF seems to like doing things like this
// otherwise you get permission errors on packet access when loading (not executing)
// the program, which indicates verifier issues
static inline struct tcphdr* parse_tcp(void *data, u64 nh_off, void *data_end) {
  struct tcphdr *tcph = data + nh_off;

  if ((void*)&tcph[1] > data_end)
    return 0;

  return tcph;
}

static inline uint16_t *parse_tcp_pld(void *data, u64 nh_off, void *data_end) {
  uint16_t *pld = data + nh_off;

  if ((void*)&pld[1] > data_end)
    return 0;

  return pld;
}

// note that context type is passed in as a parameter by BCC
int xdp_tcp_mod_prog(struct CTXTYPE *ctx) {

    void* data_end = (void*)(long)ctx->data_end;
    void* data = (void*)(long)ctx->data;

    struct ethhdr *eth = data;

    // always pass packets 
    int rc = XDP_PASS; 
    uint16_t h_proto;
    uint64_t nh_off = 0;
    struct iphdr *ip_hdr;
    struct tcphdr *tcp_hdr;
    uint16_t *tcp_pld;

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
	  tcp_pld = parse_tcp_pld(data, nh_off, data_end);
	  // note that syn packets may not contain any payload
	  if (tcp_pld != 0) {
	    int ret = swapu16(tcp_pld, data_end, 2, 4);
	    //bpf_trace_printk("tcp_header length %d ret=%d\n", tcp_hdr->doff, ret);
	  } 
	}
      }
    }

    return rc;
}
