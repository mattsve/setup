# Caddy reverse proxy for the web UIs. Moved from pve1
# (tofu/pve1/lxc_reverse_proxy.tf) with `pct remote-migrate`, root disk and MAC
# intact, then adopted here via `tofu import`
# (module.reverse_proxy01.proxmox_virtual_environment_container.this
# <node>/105) - see modules/ha_container and CLAUDE.md.
module "reverse_proxy01" {
  source = "./modules/ha_container"

  name      = "reverse-proxy01"
  vm_id     = 105
  # Creation node only (HA decides where it runs); pve03 is its preferred
  # home via ha_nodes below, but it was migrated in onto pve01.
  node_name = "pve01"

  # Only used on create; an imported container keeps whatever it was built from.
  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  bridge = proxmox_sdn_vnet.server.id
  # Unchanged from pve1, so the SLAAC ULA stays
  # fd01:eae3:bc39:32:be24:11ff:fecb:eab5
  mac_address = "BC:24:11:CB:EA:B5"
  # DHCP (module default) - dnsUpdates registers the lease as
  # reverse-proxy01.server.agb.ingenstans.se (host_vars/dns01.yaml).

  tags = ["managed-updates", "autologin", "certbot", "caddy"]

  # DHCP-addressed on VLAN 50, which dns01/dns02 serve - needs them
  # (order=1) up first to get a lease at all.
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
