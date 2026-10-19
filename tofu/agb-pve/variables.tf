variable "proxmox_token_secret" {
  description = "Secret half of the root@pam!opentofu API token (see tofu/agb-pve/.env)"
  type        = string
  sensitive   = true
}
