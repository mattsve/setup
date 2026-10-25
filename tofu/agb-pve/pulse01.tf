# Pulse monitoring dashboard (installed by the ansible `pulse` role). Recreated
# rather than migrated, as it holds no state worth carrying over.
module "pulse01" {
  source = "./modules/ha_container"

  name      = "pulse01"
  vm_id     = 104
  node_name = "pve02"

  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  bridge = proxmox_sdn_vnet.server.id
  # Pinned: the SLAAC ULA (fd01:eae3:bc39:32:be24:11ff:fef7:4b74) derives from it.
  mac_address = "BC:24:11:F7:4B:74"
  # DHCP (module default); the lease registers in DNS via dnsUpdates.

  tags = ["managed-updates", "autologin", "pulse"]

  # Needs dns01/dns02 (order=1) up first to get a DHCP lease.
  startup = {
    order    = 2
    up_delay = 0
  }

  cores = 2
  # 512 wasn't enough: the install script was OOM-killed (rc 137).
  memory    = 1024
  swap      = 256
  disk_size = 2

  # Pulse is unauthenticated, so only reverse-proxy01 (by its stable ULA) may
  # reach it.
  firewall_rules = [
    {
      proto   = "tcp"
      dport   = "7655"
      source  = "fd01:eae3:bc39:32:be24:11ff:fecb:eab5"
      comment = "reverse-proxy01 only"
    },
  ]

  replicate_to = ["pve01", "pve03"]
  ha_nodes = {
    pve02 = 2
    pve01 = 1
    pve03 = 1
  }

  depends_on = [proxmox_sdn_applier.applier]
}
