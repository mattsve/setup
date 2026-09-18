resource "proxmox_virtual_environment_container" "reverse_proxy" {
  node_name     = "pve1"
  vm_id         = 105
  start_on_boot = true
  started       = true
  unprivileged  = true
  tags          = ["managed-updates", "autologin", "certbot", "caddy"]

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

  disk {
    datastore_id = "storage-zfs"
    size         = 2
  }

  features {
    nesting = true
  }

  initialization {
    hostname = "reverse-proxy01"
    ip_config {
      ipv4 {
        # DHCP, not static - no chicken-and-egg constraint here like dns01's,
        # so this follows pulse01's pattern instead. Lease auto-registers as
        # reverse-proxy01.server.agb.ingenstans.se (see technitium_dhcp_scopes'
        # dnsUpdates, ansible/inventory/host_vars/dns01.yaml).
        address = "dhcp"
      }
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
    # ULA (fd01:eae3:bc39:50::/64): fd01:eae3:bc39:50:be24:11ff:fecb:eab5
    mac_address = "BC:24:11:CB:EA:B5"
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
