resource "proxmox_virtual_environment_vm" "plex" {
  name      = "plex01"
  node_name = "pve1"
  vm_id     = 103
  tags      = ["managed-updates", "plex", "autologin"]
  on_boot   = true
  started   = true

  # DHCP-addressed on VLAN 50 (below), which dns01 serves - needs dns01
  # (order=1, tofu/lxc_dns.tf) up first to get a lease at all.
  startup {
    order = 2
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 4
  }

  # floating == dedicated keeps the balloon device attached (so Proxmox
  # reports real guest-reported usage instead of an RSS-based estimate -
  # per Proxmox's own docs, the device stays useful even for "fixed"
  # memory) without giving the host any room to actually reclaim from it.
  memory {
    dedicated = 4096
    floating  = 4096
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "storage-zfs"
    interface    = "scsi0"
    import_from  = proxmox_download_file.debian_13_genericcloud.id
    size         = 32
    iothread     = true
  }

  initialization {
    datastore_id        = "storage-zfs"
    interface           = "ide2"
    vendor_data_file_id = proxmox_virtual_environment_file.vm_vendor_data.id

    ip_config {
      ipv4 {
        # DHCP, not static like dns01 - no chicken-and-egg constraint here.
        # Lease auto-registers as plex01.server.agb.ingenstans.se
        # (technitium_dhcp_scopes' dnsUpdates, host_vars/dns01.yaml).
        address = "dhcp"
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ansible_ssh_public_key]
    }
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = 50
    # Pinned so SLAAC's EUI-64 derivation stays stable across rebuilds (see
    # CLAUDE.md's IPv6 addressing section). ULA: fd01:eae3:bc39:50:be24:11ff:fe82:633b
    mac_address = "BC:24:11:82:63:3B"
  }

  operating_system {
    type = "l26"
  }
}
