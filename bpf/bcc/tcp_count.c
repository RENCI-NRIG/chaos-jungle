#define KBUILD_MODNAME "foo"
#include <uapi/linux/bpf.h>
#include <linux/in.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/if_vlan.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/ipv6.h>
#include <bcc/proto.h>


// count TCP SYN packets

// count SYN packets to port 22, port 80 and 'other'
BPF_ARRAY(flowcnt, uint32_t, 3);

//BPF_TABLE("percpu_array", uint32_t, long, flowcnt, 256);

// get IP protocol
static inline struct iphdr* parse_ipv4(void *data, u64 nh_off, void *data_end) {
    struct iphdr *iph = data + nh_off;

    if ((void*)&iph[1] > data_end)
        return 0;
    return iph;
}

// get IPv6 protocol
static inline int parse_ipv6(void *data, u64 nh_off, void *data_end) {
    struct ipv6hdr *ip6h = data + nh_off;

    if ((void*)&ip6h[1] > data_end)
        return 0;
    return ip6h->nexthdr;
}

// get TCP SYN flag value
static inline struct tcphdr* parse_tcp(void *data, u64 nh_off, void *data_end) {
  struct tcphdr *tcph = data + nh_off;

  if ((void*)&tcph[1] > data_end)
    return 0;

  return tcph;
}

// note that context type is passed in as a parameter by BCC
int xdp_tcp_count_prog(struct CTXTYPE *ctx) {

    void* data_end = (void*)(long)ctx->data_end;
    void* data = (void*)(long)ctx->data;

    struct ethhdr *eth = data;

    // always pass packets 
    int rc = XDP_PASS; 
    uint16_t h_proto;
    uint64_t nh_off = 0;
    struct iphdr *ip_hdr;
    struct tcphdr *tcp_hdr;

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
	//h_proto = vhdr->h_vlan_encapsulated_proto;
    }
    if (h_proto == htons(ETH_P_8021Q) || h_proto == htons(ETH_P_8021AD)) {
        struct vlan_hdr *vhdr;

        vhdr = data + nh_off;
        nh_off += sizeof(struct vlan_hdr);
        if (data + nh_off > data_end)
            return rc;
	//h_proto = vhdr->h_vlan_encapsulated_proto;
    }

    if (h_proto == htons(ETH_P_IP)) {
      //ip_hdr = data + nh_off;
      ip_hdr = parse_ipv4(data, nh_off, data_end);
    //else if (h_proto == htons(ETH_P_IPV6))
    //   index = parse_ipv6(data, nh_off, data_end);
    } else
        ip_hdr = 0;

    if (ip_hdr != 0) {
      if (ip_hdr->protocol == IPPROTO_TCP) {
	nh_off += ip_hdr->ihl << 2;
	tcp_hdr = parse_tcp(data, nh_off, data_end);
	if (tcp_hdr != 0) {
	  //uint16_t *st = (uint16_t*)tcp_hdr;
	  //bpf_trace_printk("sport = %d\n", ntohs(tcp_hdr->source));
	  //st++;
	  //bpf_trace_printk("dport = %d\n", ntohs(tcp_hdr->dest));
	  //if (tcp_hdr->dest == htons(80)) {
	  if (tcp_hdr->syn) {
	    flowcnt.increment(0);
	  }
	}
      }
    }

    return rc;
}
