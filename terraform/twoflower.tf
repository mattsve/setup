data "template_file" "twoflower_user_data" {
  template = file("${path.module}/twoflower/cloud-config.cfg")
}

resource "libvirt_cloudinit_disk" "twoflower_init" {
  name           = "twoflower_init.iso"
  pool           = "base"
  user_data      = data.template_file.twoflower_user_data.rendered
}

resource "libvirt_volume" "twoflower" {
  name           = "twoflower.qcow2"
  pool           = "base"
  size           = 21474836480
  base_volume_id = libvirt_volume.debian-11-genericcloud.id
}

resource "libvirt_domain" "twoflower" {
  name       = "twoflower"
  vcpu       = 1
  memory     = 1024
  cloudinit  = libvirt_cloudinit_disk.twoflower_init.id
  autostart  = true
  qemu_agent = true

  disk {
    volume_id = libvirt_volume.twoflower.id
    scsi      = true
  }
  
  network_interface {
    network_id     = libvirt_network.bridge_network.id
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

   graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}