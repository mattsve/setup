# A QEMU VM on ZFS, replicated to other nodes and run under HA. Adopted rather
# than created: it was moved here from another cluster with its disks intact,
# so there is no source image and the disk is ignored. Cloud-init is declared
# as on pve1 (the ansible user is what Ansible connects as). HA, not Tofu,
# decides where it runs afterwards: node_name is only the creation node (see
# ha_container for why).
resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id
  tags      = var.tags
  on_boot   = true
  started   = true

  dynamic "startup" {
    for_each = var.startup == null ? [] : [var.startup]
    content {
      order    = startup.value.order
      up_delay = startup.value.up_delay
    }
  }

  agent {
    enabled = true
  }

  bios = var.bios

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
    floating  = var.memory
  }

  scsi_hardware = "virtio-scsi-single"

  dynamic "efi_disk" {
    for_each = var.bios == "ovmf" ? [1] : []
    content {
      datastore_id = var.disk_datastore
      type         = "4m"
    }
  }

  disk {
    datastore_id = var.disk_datastore
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = true
    # The provider's default is false, which excludes the disk from
    # storage replication jobs.
    replicate = true
  }

  # Skipped for appliance images (HAOS) that don't run cloud-init.
  dynamic "initialization" {
    for_each = var.cloud_init ? [1] : []
    content {
      datastore_id        = var.disk_datastore
      interface           = "ide2"
      vendor_data_file_id = var.vendor_data_file_id

      ip_config {
        ipv4 {
          address = "dhcp"
        }
      }

      user_account {
        username = "ansible"
        keys     = [var.ansible_ssh_public_key]
      }
    }
  }

  network_device {
    bridge      = var.bridge
    mac_address = var.mac_address
    firewall    = var.nic_firewall
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # cdrom: an adopted guest's ISO drive is empty and needn't be tracked.
    ignore_changes = [node_name, disk, efi_disk, cdrom]
  }
}
