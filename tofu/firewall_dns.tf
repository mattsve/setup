# Default-deny inbound with explicit allows for exactly the traffic dns01
# serves. Requires the cluster-wide master switch (cluster_firewall.tf) and
# net0's firewall=1 flag (lxc_dns.tf) - neither alone is enough.
resource "proxmox_virtual_environment_firewall_options" "dns" {
  node_name    = "pve1"
  container_id = proxmox_virtual_environment_container.dns.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"

  # No `dhcp` flag: dns01's IPv4 is static (lxc_dns.tf), not DHCP-leased.
  # ndp is still needed for SLAAC's Neighbor/Router Discovery traffic.
  ndp = true
}

resource "proxmox_virtual_environment_firewall_rules" "dns" {
  node_name    = "pve1"
  container_id = proxmox_virtual_environment_container.dns.vm_id

  # LAN side included too since OPNsense/AdGuard conditionally forwards
  # agb.ingenstans.se's internal split-horizon names to dns01 rather than
  # public DNS (see ansible/inventory/host_vars/dns01.yaml).
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "53"
    source  = "10.0.0.0/22,10.1.50.0/24,10.1.80.0/24"
    comment = "DNS from the LAN, VLAN 50, and VLAN 80"
  }

  # IPv6 counterpart, scoped to each network's ULA /64 rather than its GUA
  # range - clients get dns01 as their resolver via its ULA (RDNSS override,
  # see CLAUDE.md), and Proxmox's firewall rejects mixing IPv4/IPv6 in one
  # source list, so this can't just be folded into the rule above.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "53"
    source  = "fd01:eae3:bc39:100::/64,fd01:eae3:bc39:32::/64,fd01:eae3:bc39:50::/64"
    comment = "DNS (IPv6/ULA) from the LAN, VLAN 50, and VLAN 80"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53"
    source  = "10.0.0.0/22,10.1.50.0/24,10.1.80.0/24"
    comment = "DNS (TCP fallback) from the LAN, VLAN 50, and VLAN 80"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53"
    source  = "fd01:eae3:bc39:100::/64,fd01:eae3:bc39:32::/64,fd01:eae3:bc39:50::/64"
    comment = "DNS (TCP fallback, IPv6/ULA) from the LAN, VLAN 50, and VLAN 80"
  }

  # Direct, not relayed - dns01 sits on VLAN 50 itself, the same subnet as
  # every client it serves. Source covers client broadcasts (0.0.0.0) and
  # unicast renewals from a client's own leased address.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "67"
    source  = "0.0.0.0,10.1.50.0/24"
    comment = "DHCP (direct, not relayed) from VLAN 50 clients"
  }

  # Relayed, not direct - dns01 doesn't sit on VLAN 80, so requests arrive
  # unicast from OPNsense's VLAN 80 interface (the relay agent) rather than
  # as client broadcasts.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "67"
    source  = "10.1.80.1"
    comment = "DHCP (relayed via OPNsense) from VLAN 80"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "853"
    source  = "10.0.0.0/22,10.1.50.0/24,10.1.80.0/24"
    comment = "DNS-over-TLS from the LAN, VLAN 50, and VLAN 80"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "853"
    source  = "fd01:eae3:bc39:100::/64,fd01:eae3:bc39:32::/64,fd01:eae3:bc39:50::/64"
    comment = "DNS-over-TLS (IPv6/ULA) from the LAN, VLAN 50, and VLAN 80"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "443"
    source  = "10.0.0.0/22,10.1.50.0/24,10.1.80.0/24"
    comment = "DNS-over-HTTPS from the LAN, VLAN 50, and VLAN 80"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "443"
    source  = "fd01:eae3:bc39:100::/64,fd01:eae3:bc39:32::/64,fd01:eae3:bc39:50::/64"
    comment = "DNS-over-HTTPS (IPv6/ULA) from the LAN, VLAN 50, and VLAN 80"
  }

  # Not narrowed to a single admin source like pulse01's dashboard rule -
  # that rule compensates for Pulse having no auth; Technitium's console is
  # authenticated.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53443"
    source  = "10.0.0.0/22,10.1.50.0/24,10.1.80.0/24"
    comment = "Technitium web console (HTTPS) from the LAN, VLAN 50, and VLAN 80"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53443"
    source  = "fd01:eae3:bc39:100::/64,fd01:eae3:bc39:32::/64,fd01:eae3:bc39:50::/64"
    comment = "Technitium web console (HTTPS, IPv6/ULA) from the LAN, VLAN 50, and VLAN 80"
  }
}
