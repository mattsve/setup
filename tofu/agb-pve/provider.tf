provider "proxmox" {
  endpoint  = "https://pve01.management.agb.ingenstans.se:8006/"
  api_token = "root@pam!opentofu=${var.proxmox_token_secret}"
  insecure  = false
}
