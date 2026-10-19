# Proxmox Backup Server. Adopted via `tofu import proxmox_virtual_environment_vm.pbs pve1/102`,
# not created by Tofu: it was installed by hand from the PBS ISO (since
# ejected, leaving an empty ide2 drive), so there's no source image to
# import_from. This file documents its settings and surfaces drift in
# `tofu plan`. If it ever needs recreating, restore it from backup (qmrestore)
# rather than applying this - Tofu would only produce an empty VM of the right
# shape.
resource "proxmox_virtual_environment_vm" "pbs" {
  name      = "pbs01"
  node_name = "pve1"
  vm_id     = 102
  on_boot   = true
  started   = true

  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

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
    size         = 50
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
  }

  # Pinned MAC, on the management VLAN (VLAN 10) alongside pve1, with the
  # Proxmox firewall enabled on the NIC.
  network_device {
    bridge      = "vmbr0"
    vlan_id     = 10
    mac_address = "BC:24:11:A5:71:CB"
    firewall    = true
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
    # Disk content isn't reproducible from Tofu (restored from backup), and
    # the empty cdrom drive doesn't need to be tracked.
    ignore_changes = [disk, efi_disk, cdrom]
  }
}
