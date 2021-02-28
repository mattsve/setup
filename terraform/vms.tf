resource "proxmox_vm_qemu" "vimes" {
  count             = 1
  name              = "vimes"
  target_node       = "atuin"

  clone             = "ubuntu-2004-cloudinit-template"

  os_type           = "cloud-init"
  cores             = 4
  sockets           = "1"
  cpu               = "host"
  memory            = 16384
  balloon           = 1
  scsihw            = "virtio-scsi-pci"
  bootdisk          = "scsi0"
  agent             = 1

  disk {
    size            = "64G"
    type            = "scsi"
    storage         = "local-zfs"
  }

  disk {
    size            = "512G"
    type            = "scsi"
    storage         = "store"
  }

  network {
    model           = "virtio"
    bridge          = "vmbr0"
  }

  network {
    model           = "virtio"
    bridge          = "vmbr0"
    tag             = 30
  }

  # Cloud Init Settings
  ipconfig0 = "ip=10.0.1.5/22,gw=10.0.0.1"
  ipconfig1 = "ip=10.30.1.5/22"
  ciuser = "ansible"
  sshkeys = <<EOF
  %{ for ssh_key in var.ssh_keys ~}
  ${ssh_key}
  %{ endfor ~}
  EOF
}

resource "proxmox_vm_qemu" "iot-test" {
  count             = 1
  name              = "iot-test-${count.index}"
  target_node       = "atuin"

  clone             = "ubuntu-2004-cloudinit-template"

  os_type           = "cloud-init"
  cores             = 2
  sockets           = "1"
  cpu               = "host"
  memory            = 2048
  balloon           = 1
  scsihw            = "virtio-scsi-pci"
  bootdisk          = "scsi0"
  agent             = 1

  disk {
    size            = "20G"
    type            = "scsi"
    storage         = "local-zfs"
  }

  network {
    model           = "virtio"
    bridge          = "vmbr0"
    tag             = 30
  }

  # Cloud Init Settings
  ipconfig0         = "ip=10.30.3.11${count.index + 1}/22,gw=10.30.0.1"
  ciuser = "ansible"
  sshkeys = <<EOF
  %{ for ssh_key in var.ssh_keys ~}
  ${ssh_key}
  %{ endfor ~}
  EOF
}
