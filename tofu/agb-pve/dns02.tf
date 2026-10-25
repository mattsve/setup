# Second Technitium node (cluster secondary). Mirrors dns01.tf except where noted.
module "dns02" {
  source = "./modules/ha_container"

  name      = "dns02"
  vm_id     = 107
  node_name = "pve02"

  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  # SDN VNet (sdn.tf): the VLAN tag is defined once and exists on every node.
  bridge = proxmox_sdn_vnet.server.id
  # Pinned: the SLAAC ULA (fd01:eae3:bc39:32:be24:11ff:fef8:dc3c) derives from it.
  mac_address  = "BC:24:11:F8:DC:3C"
  ipv4_address = "10.1.50.3/24"
  ipv4_gateway = "10.1.50.1"
  # Pinned to the VLAN 50 gateway, as for dns01 (see CLAUDE.md's nameserver gotcha).
  dns_servers = ["10.1.50.1"]

  tags = ["managed-updates", "autologin", "technitium", "certbot"]

  # Other guests need DNS, so hold order=2 guests back until it's listening.
  startup = {
    order    = 1
    up_delay = 30
  }

  cores = 2
  # Peak use is ~288 MiB with the HaGeZi Pro list loaded.
  memory = 1024

  # No DHCP rule: DHCP isn't clustered. See dns01.tf for why the web console
  # rule is host-enforced and has a separate ULA rule.
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
    # Cluster traffic from dns01 (sync, heartbeats). Same VLAN, so only a host
    # rule can allow it; both families since the node name has A and AAAA.
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
  # Equal priorities: required by dns01.tf's dns_apart rule.
  ha_nodes = {
    pve01 = 1
    pve02 = 1
    pve03 = 1
  }

  # Order after the SDN applier; the VNet id alone doesn't.
  depends_on = [proxmox_sdn_applier.applier]
}
