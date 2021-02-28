terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.6.7"
    }
  }
  backend "http" {
    address = "https://l-space.hem.ingenstans.se:5006/system/terraform/terraform.tfstate"
    update_method = "PUT"
  }
}

provider "proxmox" {
  pm_api_url = "https://atuin.hem.ingenstans.se:8006/api2/json"
  pm_user = "terraform@pve"
  pm_tls_insecure = true
}