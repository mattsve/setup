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
        address = "10.1.50.2/24"
        gateway = "10.1.50.1"
      }
    }
    # Overrides the datacenter-wide default nameserver (10.0.0.1, OPNsense's
    # LAN address). AdGuard Home replies to queries from its VLAN-50-facing
    # address (10.1.50.1), not the address queried, so a client asking
    # 10.0.0.1 gets a reply from a different source address and silently
    # drops it as a mismatch.
    dns {
      servers = ["10.1.50.1"]
    }
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 50
    # Pinned so SLAAC's EUI-64 derivation stays stable across rebuilds - see
    # the IPv6 addressing note in CLAUDE.md. Resulting address on VLAN 50's
    # ULA (fd01:eae3:bc39:50::/64): fd01:eae3:bc39:50:be24:11ff:fe7d:ccf0
    mac_address = "BC:24:11:7D:CC:F0"
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
