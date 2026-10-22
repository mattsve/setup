# MQTT broker (Mosquitto). Moved from pve1 (tofu/pve1/lxc_mqtt.tf) with
# `pct remote-migrate`, root disk and MAC intact, then adopted here via
# `tofu import` (module.mqtt01.proxmox_virtual_environment_container.this
# <node>/100) - see modules/ha_container and CLAUDE.md.
module "mqtt01" {
  source = "./modules/ha_container"

  name      = "mqtt01"
  vm_id     = 100
  node_name = "pve01"

  # Only used on create; an imported container keeps whatever it was built from.
  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  bridge = proxmox_sdn_vnet.server.id
  # Unchanged from pve1, so the SLAAC ULA stays
  # fd01:eae3:bc39:32:be24:11ff:fe42:31c4
  mac_address = "BC:24:11:42:31:C4"
  # DHCP (module default) - dnsUpdates registers the lease as
  # mqtt01.server.agb.ingenstans.se (host_vars/dns01.yaml).

  tags = ["managed-updates", "certbot", "autologin", "mosquitto"]

  # DHCP-addressed on VLAN 50, which dns01 serves - needs dns01/dns02
  # (order=1) up first to get a lease at all.
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
