# Default-deny inbound; var.firewall_rules lists what is let through. Which
# VLANs can reach the guest at all is OPNsense's job (inter-VLAN policy lives
# there), so rules without a source accept from anywhere. A source is for the
# few things OPNsense can't police, e.g. traffic from the guest's own VLAN.
resource "proxmox_virtual_environment_firewall_options" "this" {
  node_name    = var.node_name
  container_id = proxmox_virtual_environment_container.this.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"

  # Lets a DHCP-addressed guest's lease traffic through the DROP policy; a
  # static guest doesn't need it.
  dhcp = var.ipv4_address == "dhcp"
  # ndp is still needed for SLAAC's Neighbor/Router Discovery traffic.
  ndp = true
}

resource "proxmox_virtual_environment_firewall_rules" "this" {
  node_name    = var.node_name
  container_id = proxmox_virtual_environment_container.this.vm_id

  dynamic "rule" {
    for_each = var.firewall_rules
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = rule.value.proto
      dport   = rule.value.dport
      source  = rule.value.source
      comment = rule.value.comment
    }
  }
}
