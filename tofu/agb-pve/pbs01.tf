# Proxmox Backup Server, moved from pve1 (tofu/pve1/vm_pbs.tf) with its disks
# intact and adopted here via `tofu import`
# (module.pbs01.proxmox_virtual_environment_vm.this <node>/102). It was
# installed by hand from the PBS ISO, so there's no source image or cloud-init:
# the module's disk/efi_disk/cdrom are ignored, and the guest's network config
# lives inside PBS itself.
#
# On the storage VLAN (VLAN 20) instead of management, statically addressed
# inside the guest at 10.1.20.2/24 (gateway 10.1.20.1) - not DHCP, so it never
# depends on dns01 being up to be reachable for restores. MAC unchanged, so
# its SLAAC ULA there is fd01:eae3:bc39:14:be24:11ff:fea5:71cb.
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
