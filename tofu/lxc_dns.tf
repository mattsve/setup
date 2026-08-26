resource "proxmox_virtual_environment_container" "dns" {
  node_name     = "pve1"
  vm_id         = 106
  start_on_boot = true
  started       = true
  unprivileged  = true
  tags          = ["managed-updates", "autologin", "technitium"]

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  disk {
    datastore_id = "storage-zfs"
    size         = 4
  }

  features {
    nesting = true
  }

  initialization {
    hostname = "dns01"
    ip_config {
      ipv4 {
        address = "10.0.2.6/22"
        gateway = "10.0.0.1"
      }
    }
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
    # Pinned so SLAAC's EUI-64 derivation stays stable across rebuilds - see
    # the IPv6 addressing note in CLAUDE.md. Resulting address on the LAN's
    # ULA (fd01:eae3:bc39:100::/64): fd01:eae3:bc39:100:be24:11ff:fe7d:ccf0
    mac_address = "BC:24:11:7D:CC:F0"
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
