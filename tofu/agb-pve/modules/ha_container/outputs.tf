output "ha_resource_id" {
  description = "HA resource id (ct:<vmid>), for cross-guest rules such as resource affinity"
  value       = proxmox_haresource.this.resource_id
}
