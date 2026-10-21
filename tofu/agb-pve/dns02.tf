# Second Technitium node, built first on the new cluster to try out SDN, ZFS
# replication and HA before anything else moves over. Mirrors dns01
# (tofu/pve1/lxc_dns.tf) except where noted.
module "dns02" {
  source = "./modules/ha_container"

  name      = "dns02"
  vm_id     = 107
  node_name = "pve02"

  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  # SDN VNet (sdn.tf) instead of vmbr0 + vlan_id: the VLAN tag is defined
  # once on the VNet, and the VNet exists on every node.
  bridge = proxmox_sdn_vnet.server.id
  # Pinned so SLAAC's EUI-64 derivation stays stable across rebuilds (see
  # CLAUDE.md's IPv6 addressing section). ULA: fd01:eae3:bc39:32:be24:11ff:fef8:dc3c
  mac_address  = "BC:24:11:F8:DC:3C"
  ipv4_address = "10.1.50.3/24"
  ipv4_gateway = "10.1.50.1"
  # Pinned to the VLAN 50 gateway for the same reason as dns01 (see
  # tofu/pve1/lxc_dns.tf).
  dns_servers = ["10.1.50.1"]

  # technitium + certbot: host_vars/dns02.yaml (cert names, cluster join)
  # exists now, so the guest can be configured as dns01's cluster secondary.
  tags = ["managed-updates", "autologin", "technitium", "certbot"]

  # Other guests depend on DNS being up, so hold order=2 guests back until
  # it's listening. (dns02 doesn't serve DHCP, unlike dns01.)
  startup = {
    order    = 1
    up_delay = 30
  }

  cores = 2
  # dns01 was given 4096 generously but has never used more than ~288 MiB
  # (HaGeZi Pro list loaded), so 1 GiB leaves ample headroom for list
  # updates and the install script's tarball re-extract on every play.
  memory = 1024

  # No DHCP rule: unlike dns01, dns02 doesn't serve DHCP (Technitium's cluster
  # feature doesn't cover it). The web console is the one rule that stays
  # host-enforced, since dns02 sits on VLAN 50 itself and VLAN 50-sourced
  # traffic to it never transits OPNsense. Its IPv6 counterpart uses the ULA
  # /64 rather than a GUA range: clients reach dns02 via its ULA (RDNSS
  # override, see CLAUDE.md), and Proxmox's firewall rejects mixing IPv4/IPv6
  # in one source list.
  firewall_rules = [
    { proto = "udp", dport = "53", comment = "DNS" },
    { proto = "tcp", dport = "53", comment = "DNS (TCP fallback)" },
    { proto = "tcp", dport = "853", comment = "DNS-over-TLS" },
    { proto = "tcp", dport = "443", comment = "DNS-over-HTTPS" },
    {
      proto   = "tcp"
      dport   = "53443"
      source  = "10.1.100.0/24"
      comment = "Technitium web console (HTTPS) - main (VLAN 100) only"
    },
    {
      proto   = "tcp"
      dport   = "53443"
      source  = "fd01:eae3:bc39:64::/64"
      comment = "Technitium web console (HTTPS, IPv6/ULA) - main (VLAN 100) only"
    },
    # Cluster traffic: dns01 (the primary) calls dns02's web service to sync
    # and for heartbeats. Same VLAN, so it never transits OPNsense - only a
    # host rule can allow it. Both families, as the node name has an A and AAAA.
    {
      proto   = "tcp"
      dport   = "53443"
      source  = "10.1.50.2"
      comment = "Technitium cluster - dns01 (IPv4)"
    },
    {
      proto   = "tcp"
      dport   = "53443"
      source  = "fd01:eae3:bc39:32:be24:11ff:fe7d:ccf0"
      comment = "Technitium cluster - dns01 (IPv6/ULA)"
    },
  ]

  # Replicated to both other nodes so HA can restart it on either.
  replicate_to = ["pve01", "pve03"]
  ha_nodes = {
    pve02 = 2
    pve01 = 1
    pve03 = 1
  }

  # The VNet only carries traffic once the applier has pushed SDN to the
  # nodes; referencing its id alone doesn't order against that.
  depends_on = [proxmox_sdn_applier.applier]
}
