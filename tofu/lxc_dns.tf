resource "proxmox_virtual_environment_container" "dns" {
  node_name     = "pve1"
  vm_id         = 106
  start_on_boot = true
  started       = true
  unprivileged  = true
  # certbot: dns01 holds its own cert (converted to PKCS#12 for Technitium)
  # so it can terminate DNS-over-TLS/HTTPS and its web console directly
  # rather than behind reverse-proxy01's caddy - DoT is raw TLS-wrapped DNS,
  # not HTTP, so a proxy in front couldn't terminate it anyway.
  tags = ["managed-updates", "autologin", "technitium", "certbot"]

  # dns01 is the DHCP server for VLAN 50, so other VLAN 50 guests can't get
  # a lease until it's up. order=1 plus up_delay holds order=2 guests back
  # 30s, giving dns.service and the DHCP scope time to actually be
  # listening rather than racing them.
  startup {
    order    = 1
    up_delay = 30
  }

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
    # Overrides the datacenter-wide default nameserver (10.0.0.1). AdGuard
    # Home replies from its VLAN-50-facing address (10.1.50.1) instead of
    # the address queried, so a client asking 10.0.0.1 silently drops the
    # reply as a source mismatch.
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
    # Pinned so SLAAC's EUI-64 derivation stays stable across rebuilds (see
    # CLAUDE.md's IPv6 addressing section). ULA: fd01:eae3:bc39:50:be24:11ff:fe7d:ccf0
    mac_address = "BC:24:11:7D:CC:F0"
    # Required for firewall_dns.tf's rules to actually filter this
    # interface - without it Proxmox compiles the firewall config but never
    # attaches it to net0.
    firewall = true
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
