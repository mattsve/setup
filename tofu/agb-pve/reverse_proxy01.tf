# Caddy reverse proxy for the web UIs. Moved from pve1 with `pct remote-migrate`
# and adopted via `tofu import` (see CLAUDE.md).
module "reverse_proxy01" {
  source = "./modules/ha_container"

  name      = "reverse-proxy01"
  vm_id     = 105
  # Creation node only; HA decides where it runs (pve03 is preferred, below).
  node_name = "pve01"

  # Only used on create; an imported container keeps whatever it was built from.
  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  bridge = proxmox_sdn_vnet.server.id
  # Pinned: the SLAAC ULA (fd01:eae3:bc39:32:be24:11ff:fecb:eab5) derives from it.
  mac_address = "BC:24:11:CB:EA:B5"
  # DHCP (module default); the lease registers in DNS via dnsUpdates.

  tags = ["managed-updates", "autologin", "certbot", "caddy"]

  # Needs dns01/dns02 (order=1) up first to get a DHCP lease.
  startup = {
    order    = 2
    up_delay = 0
  }

  disk_size = 2

  firewall_rules = [
    { proto = "tcp", dport = "443", comment = "HTTPS (Caddy vhosts)" },
    { proto = "tcp", dport = "80", comment = "HTTP (Caddy redirect to HTTPS)" },
  ]

  replicate_to = ["pve02", "pve03"]
  ha_nodes = {
    pve03 = 2
    pve01 = 1
    pve02 = 1
  }

  depends_on = [proxmox_sdn_applier.applier]
}
