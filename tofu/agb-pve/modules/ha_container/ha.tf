# ZFS replication (no shared storage) gives HA something to fail over to.
# Proxmox rewrites a job's target when the guest moves (a job can't replicate
# to its own node), so `target` is ignored. Job numbers are the position in
# var.replicate_to, so only ever append to that list.
resource "proxmox_replication" "this" {
  for_each = { for i, node in var.replicate_to : node => i }

  id       = "${var.vm_id}-${each.value}"
  target   = each.key
  type     = "local"
  schedule = var.replication_schedule
  comment  = "${var.name} -> ${each.key}"

  lifecycle {
    ignore_changes = [target]
  }
}

resource "proxmox_haresource" "this" {
  resource_id = "ct:${proxmox_virtual_environment_container.this.vm_id}"
  state       = "started"
  comment     = "Managed by Tofu"

  # Don't put it under HA before there is something replicated to fail over to.
  depends_on = [proxmox_replication.this]
}

# PVE 9 replaced HA groups with rules. Non-strict, so it may run on any node
# if its preferred ones are down.
resource "proxmox_harule" "this" {
  rule      = var.name
  type      = "node-affinity"
  resources = [proxmox_haresource.this.resource_id]
  strict    = false
  comment   = "${var.name} node preference"
  nodes     = var.ha_nodes
}
