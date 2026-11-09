# Forgejo git host (installed by the ansible `forgejo` role). Internal only:
# web UI via reverse-proxy01, git over SSH straight to this guest.
module "git01" {
  source = "./modules/ha_container"

  name      = "git01"
  vm_id     = 108
  node_name = "pve03"

  template_file_id = proxmox_download_file.debian_13_standard_pve03.id

  bridge = proxmox_sdn_vnet.server.id
  # Pinned: the SLAAC ULA (fd01:eae3:bc39:32:be24:11ff:fea7:3c5e) derives from it.
  mac_address = "BC:24:11:A7:3C:5E"
  # DHCP (module default); the lease registers in DNS via dnsUpdates.

  # "ssh" keeps sshd on (unused_services disables it otherwise): git clones
  # use the host's sshd, locked down to the git user by the forgejo role.
  tags = ["managed-updates", "autologin", "ssh", "forgejo"]

  # Needs dns01/dns02 (order=1) up first to get a DHCP lease.
  startup = {
    order    = 2
    up_delay = 0
  }

  cores     = 2
  memory    = 1024
  swap      = 256
  disk_size = 16 # repos and the SQLite database live on the root disk

  firewall_rules = [
    {
      proto   = "tcp"
      dport   = "3000"
      source  = "fd01:eae3:bc39:32:be24:11ff:fecb:eab5"
      comment = "Forgejo web UI, reverse-proxy01 only"
    },
    { proto = "tcp", dport = "22", comment = "git over SSH" },
  ]

  replicate_to = ["pve01", "pve02"]
  ha_nodes = {
    pve03 = 2
    pve01 = 1
    pve02 = 1
  }

  depends_on = [proxmox_sdn_applier.applier]
}
