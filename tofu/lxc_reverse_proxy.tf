resource "proxmox_virtual_environment_container" "reverse_proxy" {
  node_name     = "pve1"
  vm_id         = 105
  start_on_boot = true
  started       = true
  unprivileged  = true
  tags          = ["managed-updates", "autologin", "certbot", "caddy"]

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
        address = "10.0.2.5/22"
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
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
