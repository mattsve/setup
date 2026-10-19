resource "proxmox_virtual_environment_container" "pulse" {
  node_name     = "pve1"
  vm_id         = 104
  start_on_boot = true
  started       = true
  unprivileged  = true
  tags          = ["managed-updates", "autologin", "pulse"]

  # DHCP-addressed on VLAN 50 (below), which dns01 serves - needs dns01
  # (order=1, lxc_dns.tf) up first to get a lease at all.
  startup {
    order = 2
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  cpu {
    cores = 2
  }

  disk {
    datastore_id = "storage-zfs"
    size         = 2
  }

  features {
    nesting = true
  }

  initialization {
    hostname = "pulse01"
    ip_config {
      ipv4 {
        # DHCP - dnsUpdates registers this lease as
        # pulse01.server.agb.ingenstans.se automatically (host_vars/dns01.yaml).
        address = "dhcp"
      }
    }
  }

  memory {
    # 512 wasn't enough - the install script's extraction/setup step got
    # OOM-killed (rc 137, no output) at that size.
    dedicated = 1024
    swap      = 256
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 50
    # Pinned so SLAAC's EUI-64 derivation stays stable across rebuilds (see
    # CLAUDE.md's IPv6 addressing section). ULA: fd01:eae3:bc39:32:be24:11ff:fef7:4b74
    mac_address = "BC:24:11:F7:4B:74"
    # Required for firewall_pulse.tf's rules to actually filter this
    # interface - without it Proxmox compiles the firewall config but never
    # attaches it to net0.
    firewall = true
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
