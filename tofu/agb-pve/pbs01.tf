# Proxmox Backup Server, moved from pve1 and adopted via `tofu import`. It was
# installed by hand from the PBS ISO, so there is no source image or cloud-init;
# disk/efi_disk/cdrom are ignored and its network config lives inside PBS.
#
# On the storage VLAN (20), static 10.1.20.2/24 inside the guest (gateway
# 10.1.20.1) so restores never depend on dns01. MAC pinned; ULA is
# fd01:eae3:bc39:14:be24:11ff:fea5:71cb.
module "pbs01" {
  source = "./modules/ha_vm"

  name      = "pbs01"
  vm_id     = 102
  node_name = "pve03"

  bridge       = proxmox_sdn_vnet.storage.id
  mac_address  = "BC:24:11:A5:71:CB"
  nic_firewall = true

  bios       = "ovmf"
  cpu_type   = "x86-64-v2-AES"
  cloud_init = false

  cores     = 4
  memory    = 4096
  disk_size = 50

  replicate_to = ["pve01", "pve02"]
  ha_nodes = {
    pve01 = 1
    pve02 = 1
    pve03 = 2
  }

  depends_on = [proxmox_sdn_applier.applier]
}
