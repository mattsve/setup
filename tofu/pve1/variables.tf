variable "proxmox_token_secret" {
  description = "Secret half of the root@pam!ansible API token (see tofu/.env)"
  type        = string
  sensitive   = true
}

variable "ansible_ssh_public_key" {
  description = "SSH public key for the cloud-init 'ansible' user on VMs"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINWhE59wyLWzBYryXzT37R4km5c7JJhgKQ+gejOGdhxT"
}
