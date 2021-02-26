terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "2.6.7"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://atuin.hem.ingenstans.se:8006/api2/json"
  pm_user = "terraform@pve"
  pm_tls_insecure = true
}