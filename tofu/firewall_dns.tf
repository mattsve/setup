# dns01 previously had no per-guest firewall at all (unlike pulse01's -
# see firewall_pulse.tf), leaving DNS/DHCP/web console wide open to every
# host that can route to VLAN 50. This locks it down to a default-deny
# inbound policy with explicit allows for exactly the traffic dns01 is
# meant to serve. Requires the cluster-wide master switch
# (cluster_firewall.tf) and net0's firewall=1 flag (lxc_dns.tf) - neither
# alone is enough for this resource's rules to take effect.
resource "proxmox_virtual_environment_firewall_options" "dns" {
  node_name    = "pve1"
  container_id = proxmox_virtual_environment_container.dns.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"

  # No `dhcp` flag: unlike pulse01/reverse-proxy01, dns01's own IPv4 is
  # static (lxc_dns.tf's ip_config), not DHCP-leased, so it never needs the
  # client-side DHCP ports for itself. ndp is still needed for the
  # Neighbor/Router Discovery traffic SLAAC needs for its IPv6 ULA/GUA (see
  # CLAUDE.md's IPv6 addressing section).
  ndp = true
}

resource "proxmox_virtual_environment_firewall_rules" "dns" {
  node_name    = "pve1"
  container_id = proxmox_virtual_environment_container.dns.vm_id

  # Plain DNS. VLAN 50 clients use dns01 directly (technitium_dhcp_scopes'
  # useThisDnsServer); the LAN side is included too since OPNsense/AdGuard
  # conditionally forwards agb.ingenstans.se's internal split-horizon names
  # to dns01 rather than public DNS (see the zone comments in
  # ansible/inventory/host_vars/dns01.yaml) - unlike pulse01's single-peer
  # rule, this has to admit a whole subnet of arbitrary clients, not one
  # known consumer.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "53"
    source  = "10.0.0.0/22,10.1.50.0/24"
    comment = "DNS from the LAN and VLAN 50"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53"
    source  = "10.0.0.0/22,10.1.50.0/24"
    comment = "DNS (TCP fallback) from the LAN and VLAN 50"
  }

  # Plain DHCP, not relayed: dns01 sits directly on VLAN 50 (10.1.50.0/24),
  # the same subnet as every client it serves, so there's no L3 hop for a
  # relay to bridge - clients' broadcast DHCPDISCOVERs already reach it
  # directly over L2. OPNsense previously also had DHCP relay/IP Helper
  # enabled for VLAN 50 pointed at dns01 on top of that, which is where
  # mqtt01's "no DHCPOFFERS received" actually came from: relayed requests
  # carry a non-zero giaddr, which tells the server to reply to the relay
  # agent rather than the client directly, and that same-subnet relay
  # return leg was the broken part - not this firewall rule, which a
  # counter check had already shown accepting the relayed copies fine.
  # Widening the rule to any source earlier "fixed" mqtt01 only because it
  # incidentally let mqtt01's own direct broadcast (source 0.0.0.0) through
  # too, which the strict 10.1.50.1-only rule had been silently dropping
  # the whole time. Now that the relay is off on OPNsense, narrowed back to
  # the actual source shape direct DHCP traffic has: client broadcasts from
  # 0.0.0.0, and unicast renewals from a client's own leased VLAN 50
  # address - both covered by the whole subnet rather than a single peer.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "udp"
    dport   = "67"
    source  = "0.0.0.0,10.1.50.0/24"
    comment = "DHCP (direct, not relayed) from VLAN 50 clients"
  }

  # DNS-over-TLS (ansible/roles/technitium's enableDnsOverTls) and DNS-over-
  # HTTPS (enableDnsOverHttps) - encrypted alternatives to plain port 53
  # for the same LAN + VLAN 50 clients above.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "853"
    source  = "10.0.0.0/22,10.1.50.0/24"
    comment = "DNS-over-TLS from the LAN and VLAN 50"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "443"
    source  = "10.0.0.0/22,10.1.50.0/24"
    comment = "DNS-over-HTTPS from the LAN and VLAN 50"
  }

  # Technitium's web console, served directly over HTTPS (webServiceTlsPort
  # in ansible/roles/technitium) rather than reverse-proxied - not narrowed
  # to a single admin source the way pulse01's dashboard is, since that
  # rule exists to compensate for Pulse having no auth of its own;
  # Technitium's console is authenticated.
  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "53443"
    source  = "10.0.0.0/22,10.1.50.0/24"
    comment = "Technitium web console (HTTPS) from the LAN and VLAN 50"
  }
}
