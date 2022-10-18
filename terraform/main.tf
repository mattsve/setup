terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
  backend "http" {
    address = "https://l-space.hem.ingenstans.se:5006/system/terraform/terraform.tfstate"
    update_method = "PUT"
  }
}

provider "libvirt" {
  uri = "qemu+ssh://mattias@carrot.hem.ingenstans.se/system?sshauth=privkey&keyfile=/home/mattias/.ssh/id_ecdsa"
}
