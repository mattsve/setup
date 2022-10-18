resource "libvirt_network" "bridge_network" {
  name = "bridgenet"
  mode = "bridge"
  bridge = "br0"
  autostart = true
}

resource "libvirt_pool" "base" {
  name = "base"
  type = "dir"
  path = "/storage/vm/base"
}

resource "libvirt_volume" "debian-11-genericcloud" {
  name = "debian-11-genericcloud.qcow2"
  pool = "base"
  format = "qcow2"
  source = "http://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
}

