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

  sshkeys = <<EOF
  %{ for ssh_key in var.ssh_keys ~}
  ${ssh_key}
  %{ endfor ~}
  EOF
}
