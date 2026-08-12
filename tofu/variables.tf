variable "proxmox_token_secret" {
  description = "Secret half of the root@pam!ansible API token (see tofu/.env)"
  type        = string
  sensitive   = true
}
