provider "proxmox" {
  endpoint  = "https://pve1.hem.ingenstans.se:8006/"
  api_token = "root@pam!opentofu=${var.proxmox_token_secret}"
  insecure  = false

  # The Proxmox API has no upload endpoint for "snippets" content (used by
  # vm_vendor_data in templates.tf), so the provider writes that file over
  # SSH instead of the API token above. Reuses the same root SSH access
  # Ansible already relies on for pve1 (inventory/group_vars/proxmox_nodes.yaml).
  ssh {
    agent    = true
    username = "root"
  }
}
