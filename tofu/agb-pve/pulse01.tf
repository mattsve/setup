# Pulse monitoring dashboard (installed by the ansible `pulse` role). Recreated
# here rather than migrated from pve1 (tofu/pve1/lxc_pulse.tf): it holds no
# state worth carrying over, so the MAC is reused (keeping the SLAAC ULA) and
# the role reinstalls it. Destroy the pve1 copy before applying this, since
# the MAC and hostname would otherwise collide - see modules/ha_container.
module "pulse01" {
  source = "./modules/ha_container"

  name      = "pulse01"
  vm_id     = 104
  node_name = "pve02"

  template_file_id = proxmox_download_file.debian_13_standard_pve02.id

  bridge = proxmox_sdn_vnet.server.id
  # Unchanged from pve1, so the SLAAC ULA stays
  # fd01:eae3:bc39:32:be24:11ff:fef7:4b74
  mac_address = "BC:24:11:F7:4B:74"
  # DHCP (module default) - dnsUpdates registers the lease as
  # pulse01.server.agb.ingenstans.se (host_vars/dns01.yaml).

  tags = ["managed-updates", "autologin", "pulse"]

  # DHCP-addressed on VLAN 50, which dns01/dns02 serve - needs them
  # (order=1) up first to get a lease at all.
  startup = {
    order    = 2
    up_delay = 0
  }

  cores = 2
  # 512 wasn't enough - the install script's extraction/setup step got
  # OOM-killed (rc 137, no output) at that size.
  memory    = 1024
  swap      = 256
  disk_size = 2

  # Pulse is unauthenticated by default, so only reverse-proxy01 (via its
  # stable VLAN 50 ULA, the address its caddy_proxies pulse backend connects
  # from, host_vars/reverse-proxy01.yaml) may reach the dashboard.
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
