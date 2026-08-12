provider "proxmox" {
  endpoint  = "https://pve1.hem.ingenstans.se:8006/"
  api_token = "root@pam!opentofu=${var.proxmox_token_secret}"
  insecure  = false
}
