# Home Assistant OS (VM 101). Moved from pve1 (tofu/pve1/vm_ha.tf) with its disk
# intact via `qm remote-migrate`, then adopted here via `tofu import`
# (module.ha.proxmox_virtual_environment_vm.this <node>/101) - see modules/ha_vm.
# HAOS isn't a cloud-init guest, so cloud_init is off; its network (DHCP/SLAAC)
# is configured inside HAOS. If it ever needs recreating, restore from the PBS
# backup rather than applying this.
module "ha" {
  source = "./modules/ha_vm"

  name      = "ha"
  vm_id     = 101
  node_name = "pve02"

  bridge = proxmox_sdn_vnet.server.id
  # Unchanged from pve1, so the SLAAC ULA stays
  # fd01:eae3:bc39:32:216:3eff:fe3e:6e31
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
