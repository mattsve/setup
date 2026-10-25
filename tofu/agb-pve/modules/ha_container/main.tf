# An unprivileged Debian LXC on ZFS, replicated to other nodes and run under
# HA. HA decides where it runs: node_name is only the creation node (hence
# ignore_changes below), since otherwise a container HA has moved plans a
# destroy-and-recreate, and we don't want Tofu migrating HA guests.
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
    # The provider defaults to false, which excludes the rootfs from replication.
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
    dynamic "dns" {
      for_each = length(var.dns_servers) == 0 ? [] : [var.dns_servers]
      content {
        servers = dns.value
      }
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

  # operating_system: an imported container has no template_file_id in state,
  # which the provider would treat as forcing replacement.
  lifecycle {
    ignore_changes = [node_name, operating_system]
  }
}
