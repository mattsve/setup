# MQTT broker (Mosquitto). Moved from pve1 with `pct remote-migrate` and adopted
# via `tofu import` (see CLAUDE.md).
module "mqtt01" {
  source = "./modules/ha_container"

  name      = "mqtt01"
  vm_id     = 100
  node_name = "pve01"

  # Only used on create; an imported container keeps whatever it was built from.
  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  bridge = proxmox_sdn_vnet.server.id
  # Pinned: the SLAAC ULA (fd01:eae3:bc39:32:be24:11ff:fe42:31c4) derives from it.
  mac_address = "BC:24:11:42:31:C4"
  # DHCP (module default); the lease registers in DNS via dnsUpdates.

  tags = ["managed-updates", "certbot", "autologin", "mosquitto"]

  # Needs dns01/dns02 (order=1) up first to get a DHCP lease.
  startup = {
    order    = 2
    up_delay = 0
  }

  disk_size = 2

  firewall_rules = [
    { proto = "tcp", dport = "8883", comment = "MQTT over TLS" },
    { proto = "tcp", dport = "1883", comment = "MQTT (plaintext)" },
  ]

  replicate_to = ["pve02", "pve03"]
  ha_nodes = {
    pve01 = 2
    pve02 = 1
    pve03 = 1
  }

  depends_on = [proxmox_sdn_applier.applier]
}
