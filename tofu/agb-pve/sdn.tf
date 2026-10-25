# Guest networking: a VLAN zone on vmbr1 (hand-configured on every node, see
# CLAUDE.md) with one VNet per guest VLAN. Routing, RA and DHCP live outside SDN
# (OPNsense / Technitium), so there are no subnets or IPAM here; SDN just gives
# named, tagged networks that exist on every node, which lets guests fail over.
#
# IDs are limited to 8 characters.
#
# No VNet for VLAN 10 (or any VLAN a node has its own address on): SDN would
# enslave that sub-interface into the VNet's bridge and strip the node's address.

resource "proxmox_sdn_zone_vlan" "vlans" {
  id     = "vlans"
  bridge = "vmbr1"

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_vnet" "server" {
  id    = "server"
  zone  = proxmox_sdn_zone_vlan.vlans.id
  tag   = 50
  alias = "Server (VLAN 50)"

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_vnet" "storage" {
  id    = "storage"
  zone  = proxmox_sdn_zone_vlan.vlans.id
  tag   = 20
  alias = "Storage (VLAN 20)"

  depends_on = [proxmox_sdn_applier.finalizer]
}

# Pushes pending SDN changes. Re-runs when a zone or VNet changes; the empty
# "finalizer" is the provider's pattern for applying again on destroy.
resource "proxmox_sdn_applier" "applier" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_vlan.vlans,
      proxmox_sdn_vnet.server,
      proxmox_sdn_vnet.storage,
    ]
  }

  depends_on = [
    proxmox_sdn_zone_vlan.vlans,
    proxmox_sdn_vnet.server,
    proxmox_sdn_vnet.storage,
  ]
}

resource "proxmox_sdn_applier" "finalizer" {}
