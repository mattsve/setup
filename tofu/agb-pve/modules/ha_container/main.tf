# An unprivileged Debian LXC on ZFS, replicated to other nodes and run under
# HA. HA, not Tofu, decides where it runs once it exists: node_name is only
# the creation node, hence ignore_changes below. Without it a container HA has
# moved makes Tofu plan to destroy and recreate it (provider >= 0.115 finds
# the container on its real node, but a node change still forces replacement
# unless `migrate = true`, and we don't want Tofu moving HA guests).
resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  start_on_boot = true
  started       = true
  unprivileged  = true
  tags          = var.tags

  dynamic "startup" {
    for_each = var.startup == null ? [] : [var.startup]
    content {
      order    = startup.value.order
      up_delay = startup.value.up_delay
    }
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  cpu {
    cores = var.cores
  }

  disk {
    datastore_id = var.disk_datastore
    size         = var.disk_size
    # The provider's default is false, which marks the rootfs as excluded
    # from storage replication jobs - Proxmox's own default is included.
    replicate = true
  }

  features {
    nesting = var.nesting
  }

  initialization {
    hostname = var.name
    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  network_interface {
    name        = "eth0"
    bridge      = var.bridge
    mac_address = var.mac_address
    # Required for the firewall rules below to attach to this interface.
    firewall = true
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  # operating_system: the template is only used on create, and a container
  # imported after a cross-cluster move has no template_file_id in state, which
  # the provider treats as forcing replacement (destroying the migrated disk).
  lifecycle {
    ignore_changes = [node_name, operating_system]
  }
}
