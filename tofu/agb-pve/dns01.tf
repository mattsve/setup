# Primary Technitium node and the DHCP server for VLAN 50/80. Moved from pve1
# with `pct remote-migrate` and adopted via `tofu import`. Mirrors dns02.tf
# except where noted.
module "dns01" {
  source = "./modules/ha_container"

  name      = "dns01"
  vm_id     = 106
  node_name = "pve01"

  # Only used on create; an imported container keeps whatever it was built from.
  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  bridge = proxmox_sdn_vnet.server.id
  # Pinned: the SLAAC ULA (fd01:eae3:bc39:32:be24:11ff:fe7d:ccf0) derives from it.
  mac_address  = "BC:24:11:7D:CC:F0"
  ipv4_address = "10.1.50.2/24"
  ipv4_gateway = "10.1.50.1"
  # Pinned to the VLAN 50 gateway (see CLAUDE.md's nameserver gotcha).
  dns_servers = ["10.1.50.1"]

  tags = ["managed-updates", "autologin", "technitium", "certbot"]

  # DHCP server for VLAN 50, so other VLAN 50 guests can't get a lease until
  # it's up; hold order=2 guests back until dns.service is listening.
  startup = {
    order    = 1
    up_delay = 30
  }

  cores  = 2
  memory = 1024

  firewall_rules = [
    { proto = "udp", dport = "53", comment = "DNS" },
    { proto = "tcp", dport = "53", comment = "DNS (TCP fallback)" },
    # Direct (VLAN 50, including pre-lease broadcasts) and relayed (VLAN 80)
    # requests; no source restriction, reachability is OPNsense's job.
    { proto = "udp", dport = "67", comment = "DHCP (direct and relayed)" },
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
    # Cluster traffic from dns02 (same VLAN, never transits OPNsense).
    {
      proto   = "tcp"
      dport   = "53443"
      source  = "10.1.50.3"
      comment = "Technitium cluster - dns02 (IPv4)"
    },
    {
      proto   = "tcp"
      dport   = "53443"
      source  = "fd01:eae3:bc39:32:be24:11ff:fef8:dc3c"
      comment = "Technitium cluster - dns02 (IPv6/ULA)"
    },
  ]

  # Equal priorities: Proxmox rejects a resource-affinity rule over guests
  # whose node-affinity rules have multiple priorities. Placement is left to
  # HA, with the dns_apart rule below keeping the pair on separate nodes.
  replicate_to = ["pve02", "pve03"]
  ha_nodes = {
    pve01 = 1
    pve02 = 1
    pve03 = 1
  }

  depends_on = [proxmox_sdn_applier.applier]
}

# Keep the two resolvers on different nodes. Strict: with one node left, one of
# the pair stays down rather than doubling up.
resource "proxmox_harule" "dns_apart" {
  rule      = "dns-apart"
  type      = "resource-affinity"
  affinity  = "negative"
  resources = [module.dns01.ha_resource_id, module.dns02.ha_resource_id]
  comment   = "dns01 and dns02 on separate nodes"

  # Proxmox validates against the guests' node-affinity rules, which must land first.
  depends_on = [module.dns01, module.dns02]
}
