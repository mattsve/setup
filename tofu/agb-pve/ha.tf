# Home Assistant OS (VM 101). Moved from pve1 with `qm remote-migrate` and
# adopted via `tofu import`. Not a cloud-init guest; its network is configured
# inside HAOS. If it needs recreating, restore from the PBS backup.
module "ha" {
  source = "./modules/ha_vm"

  name      = "ha"
  vm_id     = 101
  node_name = "pve02"

  bridge = proxmox_sdn_vnet.server.id
  # Pinned: the SLAAC ULA (fd01:eae3:bc39:32:216:3eff:fe3e:6e31) derives from it.
  mac_address = "00:16:3E:3E:6E:31"

  # Replication freezing wedges the Supervisor (see modules/ha_vm).
  freeze_fs = false

  cloud_init = false
  bios       = "ovmf"
  cpu_type   = "x86-64-v2-AES"

  cores     = 4
  memory    = 4096
  disk_size = 32

  replicate_to = ["pve01", "pve03"]
  # Every minute (the minimum), so a failover loses at most about a minute of
  # Home Assistant state.
  replication_schedule = "*/1"
  ha_nodes = {
    pve01 = 1
    pve02 = 2
    pve03 = 1
  }

  depends_on = [proxmox_sdn_applier.applier]
}
