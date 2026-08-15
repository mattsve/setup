resource "proxmox_virtual_environment_container" "mqtt" {
  description           = ""
  environment_variables = {}
  hook_script_file_id   = ""
  node_name             = "pve1"
  pool_id               = null
  protection            = false
  start_on_boot         = true
  started               = true
  tags                  = ["managed-updates", "certbot", "autologin", "mosquitto"]
  template              = false
  unprivileged          = true

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
    hostname = "mqtt"
    ip_config {
      ipv4 {
        address = "10.0.2.1/22"
        gateway = "10.0.0.1"
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
    mac_address  = "BC:24:11:42:31:C4"
    mtu          = 0
    name         = "eth0"
    rate_limit   = 0
    vlan_id      = 0
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_13_standard.id
    type             = "debian"
  }
}
