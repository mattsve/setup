# Home Assistant OS. Adopted via `tofu import proxmox_virtual_environment_vm.ha pve1/101`,
# not created by Tofu: it was built on an earlier system and migrated here, so
# there's no source image to import_from. This file documents its settings and
# surfaces drift in `tofu plan`. If it ever needs recreating, restore it from
# the Proxmox Backup Server backup (qmrestore) rather than applying this - Tofu
# would only produce an empty VM of the right shape.
resource "proxmox_virtual_environment_vm" "ha" {
  name      = "ha"
  node_name = "pve1"
  vm_id     = 101
  on_boot   = true
  started   = true

  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id = "storage-zfs"
    type         = "4m"
  }

  disk {
    datastore_id = "storage-zfs"
    interface    = "scsi0"
    size         = 32
    iothread     = true
  }

  # Pinned MAC (migrated from the old system). On VLAN 50 with the other
  # servers; DHCP/SLAAC (EUI-64) is configured inside HAOS, not here.
  # ULA: fd01:eae3:bc39:32:216:3eff:fe3e:6e31
  network_device {
    bridge      = "vmbr0"
    vlan_id     = 50
    mac_address = "00:16:3e:3e:6e:31"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
    # Disk content isn't reproducible from Tofu (restored from backup), and
    # the provider tends to show noise on these after an import.
    ignore_changes = [disk, efi_disk, cdrom]
  }
}
