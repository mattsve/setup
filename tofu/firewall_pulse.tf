# Restricts pulse01's dashboard (port 7655) to reverse-proxy01 only - Pulse
# is otherwise reachable, unauthenticated-by-default, to every host on
# VLAN 50. Proxmox's per-guest firewall is the natural place for this: it's
# enforced by the hypervisor regardless of what's listening inside the
# guest, unlike an in-guest firewall Ansible would have to install and
# maintain (see unused_services' note on why LXCs don't run sshd either -
# same "less exposed surface" reasoning). Requires the cluster-wide master
# switch (cluster_firewall.tf) and net0's firewall=1 flag (lxc_pulse.tf) -
# neither alone is enough for this resource's rule to take effect.
resource "proxmox_virtual_environment_firewall_options" "pulse" {
  node_name    = "pve1"
  container_id = proxmox_virtual_environment_container.pulse.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"

  # Both needed so pulse01 keeps its own addressing working under the
  # switch to default-deny inbound: dhcp lets its DHCPv4 lease replies
  # through (see its ip_config in lxc_pulse.tf), ndp lets the Neighbor/
  # Router Discovery traffic SLAAC needs for its IPv6 ULA through (see
  # CLAUDE.md's IPv6 addressing section).
  dhcp = true
  ndp  = true
}

resource "proxmox_virtual_environment_firewall_rules" "pulse" {
  node_name    = "pve1"
  container_id = proxmox_virtual_environment_container.pulse.vm_id

  rule {
    type   = "in"
    action = "ACCEPT"
    proto  = "tcp"
    dport  = "7655"
    # reverse-proxy01's stable VLAN 50 ULA (see CLAUDE.md's IPv6 addressing
    # section) - the exact address its caddy_proxies pulse backend connects
    # from (ansible/inventory/host_vars/reverse-proxy01.yaml), since that
    # backend is addressed by pulse01's own ULA and same-scope source
    # selection picks reverse-proxy01's ULA to reach it.
    source  = "fd01:eae3:bc39:50:be24:11ff:fecb:eab5"
    comment = "reverse-proxy01 only"
  }
}
