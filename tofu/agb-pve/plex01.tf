# Moved from pve1 (tofu/pve1/vm_plex.tf) with its disk intact so the Plex
# library/claim survive, then adopted here via `tofu import`
# (module.plex01.proxmox_virtual_environment_vm.this <node>/103) - see
# modules/ha_vm. DHCP-addressed on VLAN 50 like before.
module "plex01" {
  source = "./modules/ha_vm"

  name      = "plex01"
  vm_id     = 103
  node_name = "pve01"

  bridge = proxmox_sdn_vnet.server.id
  # Unchanged from pve1, so the SLAAC ULA stays
  # fd01:eae3:bc39:32:be24:11ff:fe82:633b
  mac_address = "BC:24:11:82:63:3B"

  vendor_data_file_id    = proxmox_virtual_environment_file.vm_vendor_data["pve01"].id
  ansible_ssh_public_key = var.ansible_ssh_public_key

  tags = ["autologin", "managed-updates", "plex"]

  # Needs a DHCP lease from dns01/dns02 (order=1).
  startup = {
    order    = 2
    up_delay = -1
  }

  cores     = 4
  memory    = 4096
  disk_size = 32

  replicate_to = ["pve02", "pve03"]
  ha_nodes = {
    pve01 = 2
    pve02 = 1
    pve03 = 1
  }

  depends_on = [proxmox_sdn_applier.applier]
}
