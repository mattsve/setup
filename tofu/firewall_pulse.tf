# Restricts pulse01's dashboard (port 7655) to reverse-proxy01 only - Pulse
# is otherwise unauthenticated by default. Enforced at the hypervisor level
# rather than an in-guest firewall Ansible would have to install/maintain.
# Requires the cluster-wide master switch (cluster_firewall.tf) and net0's
# firewall=1 flag (lxc_pulse.tf) - neither alone is enough.
resource "proxmox_virtual_environment_firewall_options" "pulse" {
  node_name    = "pve1"
  container_id = proxmox_virtual_environment_container.pulse.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"

  # dhcp lets pulse01's own DHCPv4 lease replies through; ndp lets SLAAC's
  # Neighbor/Router Discovery traffic through for its IPv6 ULA.
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
    # reverse-proxy01's stable VLAN 50 ULA - the address its caddy_proxies
    # pulse backend connects from (host_vars/reverse-proxy01.yaml).
    source  = "fd01:eae3:bc39:32:be24:11ff:fecb:eab5"
    comment = "reverse-proxy01 only"
  }
}
