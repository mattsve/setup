# Same ZFS replication + HA setup as ha_container; see there for the reasoning.
resource "proxmox_replication" "this" {
  for_each = { for i, node in var.replicate_to : node => i }

  id       = "${var.vm_id}-${each.value}"
  target   = each.key
  type     = "local"
  schedule = var.replication_schedule
  comment  = "${var.name} -> ${each.key}"

  depends_on = [proxmox_virtual_environment_vm.this]

  lifecycle {
    ignore_changes = [target]
  }
}

resource "proxmox_haresource" "this" {
  resource_id = "vm:${proxmox_virtual_environment_vm.this.vm_id}"
  state       = "started"
  comment     = "Managed by Tofu"

  depends_on = [proxmox_replication.this]
}

resource "proxmox_harule" "this" {
  rule      = var.name
  type      = "node-affinity"
  resources = [proxmox_haresource.this.resource_id]
  strict    = false
  comment   = "${var.name} node preference"
  nodes     = var.ha_nodes
}
