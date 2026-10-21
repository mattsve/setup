# Default-deny inbound. Which VLANs can reach dns01 at all is now OPNsense's
# job (inter-VLAN policy lives there, not per-guest here), so DNS/DHCP ports
# are open to any source. The web console is the deliberate exception: it
# stays host-enforced because dns01 sits on VLAN 50 itself, so VLAN 50-
# sourced traffic to it never transits OPNsense - only this file can keep
# VLAN 50 off the console while every VLAN still gets DNS/DHCP.
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

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "53"
    comment = "DNS"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53"
    comment = "DNS (TCP fallback)"
  }

  # Covers VLAN 50's direct clients (including their own pre-lease
  # broadcast DHCPDISCOVERs at 0.0.0.0) and VLAN 10's/VLAN 80's relayed
  # requests (arriving unicast from OPNsense's relay agent) - no source
  # restriction needed for any of them now that reachability is OPNsense's
  # job.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "67"
    comment = "DHCP (direct and relayed)"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "853"
    comment = "DNS-over-TLS"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "443"
    comment = "DNS-over-HTTPS"
  }

  # Web console: main (VLAN 100) only, deliberately not even VLAN 50 - the one rule
  # that can't move to OPNsense, since VLAN 50 traffic to dns01 never routes
  # through it.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53443"
    source  = "10.1.100.0/24"
    comment = "Technitium web console (HTTPS) - main (VLAN 100) only"
  }

  # IPv6 counterpart, scoped to the main (VLAN 100) ULA /64 rather than its GUA
  # range - clients get dns01 as their resolver via its ULA (RDNSS override,
  # see CLAUDE.md), and Proxmox's firewall rejects mixing IPv4/IPv6 in one
  # source list, so this can't just be folded into the rule above.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53443"
    source  = "fd01:eae3:bc39:64::/64"
    comment = "Technitium web console (HTTPS, IPv6/ULA) - main (VLAN 100) only"
  }

  # Cluster traffic from dns02 (the secondary, on the new cluster but the
  # same VLAN): it joins via and syncs from dns01's web service. Same VLAN,
  # so it never transits OPNsense and needs a host rule.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53443"
    source  = "10.1.50.3"
    comment = "Technitium cluster - dns02 (IPv4)"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53443"
    source  = "fd01:eae3:bc39:32:be24:11ff:fef8:dc3c"
    comment = "Technitium cluster - dns02 (IPv6/ULA)"
  }
}
