resource "proxmox_virtual_environment_container" "mqtt" {
  description           = ""
  environment_variables = {}
  hook_script_file_id   = ""
  node_name             = "pve1"
  vm_id                 = 100
  pool_id               = null
  protection            = false
  start_on_boot         = true
  started               = true
  tags                  = ["managed-updates", "certbot", "autologin", "mosquitto"]
  template              = false
  unprivileged          = true

  # DHCP-addressed on VLAN 50 (below), which dns01 serves - needs dns01
  # (order=1, tofu/lxc_dns.tf) up first to get a lease at all.
  startup {
    order = 2
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  disk {
    acl           = false
    datastore_id  = "storage-zfs"
    mount_options = []
    quota         = false
    replicate     = false
    size          = 2
  }

  features {
    fuse    = false
    keyctl  = false
    mknod   = false
    mount   = []
    nesting = true
  }

  initialization {
    hostname = "mqtt01"
    ip_config {
      ipv4 {
        # DHCP - dnsUpdates registers this lease as
        # mqtt01.server.agb.ingenstans.se automatically (host_vars/dns01.yaml).
        address = "dhcp"
      }
    }
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  network_interface {
    bridge       = "vmbr0"
    enabled      = true
    firewall     = false
    host_managed = false
    # Pinned so SLAAC's EUI-64 derivation stays stable across rebuilds (see
    # CLAUDE.md's IPv6 addressing section). ULA: fd01:eae3:bc39:32:be24:11ff:fe42:31c4
    mac_address = "BC:24:11:42:31:C4"
    mtu         = 0
    name        = "eth0"
    rate_limit  = 0
    vlan_id     = 50
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
