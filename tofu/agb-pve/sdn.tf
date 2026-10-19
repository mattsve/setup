# Guest networking for the agb-pve cluster: a VLAN zone on vmbr1 (nic1, a
# trunk port; the bridge itself is hand-configured identically on every node,
# see CLAUDE.md), with one VNet per VLAN guests can attach to. Routing, RA and
# DHCP all live outside SDN (OPNsense / Technitium), so there are deliberately
# no subnets, IPAM or DNS settings here - SDN only provides named, tagged
# networks that exist on every node, which is what lets a guest fail over.
#
# Zone and VNet IDs are limited to 8 characters.

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

resource "proxmox_sdn_vnet" "mgmt" {
  id    = "mgmt"
  zone  = proxmox_sdn_zone_vlan.vlans.id
  tag   = 10
  alias = "Management (VLAN 10)"

  depends_on = [proxmox_sdn_applier.finalizer]
}

# Pushes pending SDN changes to the cluster. Re-runs whenever a zone or VNet
# changes (replace_triggered_by); the empty "finalizer" applier is the
# provider's documented pattern so the same apply also runs on destroy, after
# the objects above are gone.
resource "proxmox_sdn_applier" "applier" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_vlan.vlans,
      proxmox_sdn_vnet.server,
      proxmox_sdn_vnet.mgmt,
    ]
  }

  depends_on = [
    proxmox_sdn_zone_vlan.vlans,
    proxmox_sdn_vnet.server,
    proxmox_sdn_vnet.mgmt,
  ]
}

resource "proxmox_sdn_applier" "finalizer" {}
