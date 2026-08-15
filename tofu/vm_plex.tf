resource "proxmox_virtual_environment_vm" "plex" {
  name      = "plex"
  node_name = "pve1"
  vm_id     = 103
  tags      = ["managed-updates", "plex"]
  on_boot   = true
  started   = true

  agent {
    enabled = true
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
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
    datastore_id = "storage-zfs"
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "10.0.2.3/22"
        gateway = "10.0.0.1"
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ansible_ssh_public_key]
    }
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }
}
