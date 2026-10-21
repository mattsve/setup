provider "proxmox" {
  endpoint  = "https://pve01.management.agb.ingenstans.se:8006/"
  api_token = "root@pam!opentofu=${var.proxmox_token_secret}"
  insecure  = false

  # The Proxmox API has no upload endpoint for "snippets" content (used by
  # vm_vendor_data in templates.tf), so the provider writes that file over
  # SSH instead. It connects to each node by the address the cluster reports
  # for it, so root's key must be accepted on every node.
  ssh {
    agent    = true
    username = "root"
  }
}
