variable "name" {
  type = string
}

variable "vm_id" {
  description = "Cluster-wide VM ID"
  type        = number
}

variable "node_name" {
  description = "Node the VM is created on. HA decides where it runs afterwards."
  type        = string
}

variable "bridge" {
  description = "SDN VNet (or bridge) for the NIC"
  type        = string
}

variable "mac_address" {
  description = "Pinned MAC, so SLAAC's EUI-64 address stays stable"
  type        = string
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  description = "Dedicated (and balloon-floor) memory in MiB"
  type        = number
  default     = 2048
}

variable "disk_datastore" {
  type    = string
  default = "local-zfs"
}

variable "disk_size" {
  description = "Boot disk size in GiB"
  type        = number
}

variable "startup" {
  type = object({
    order    = number
    up_delay = number
  })
  default = null
}

variable "replicate_to" {
  description = "Nodes to replicate to. Job numbers follow list order, so only append."
  type        = list(string)
}

variable "replication_schedule" {
  type    = string
  default = "*/15"
}

variable "ha_nodes" {
  type = map(number)
}

variable "cloud_init" {
  description = "Attach a cloud-init drive (ansible user + vendor data). Off for appliance images like HAOS."
  type        = bool
  default     = true
}

variable "vendor_data_file_id" {
  description = "Cloud-init vendor data snippet (installs qemu-guest-agent)"
  type        = string
  default     = null
}

variable "ansible_ssh_public_key" {
  description = "SSH public key for the cloud-init 'ansible' user"
  type        = string
  default     = null
}

variable "bios" {
  description = "seabios, or ovmf (UEFI; adds an EFI disk)"
  type        = string
  default     = "seabios"
}

variable "cpu_type" {
  description = "CPU model; null keeps the provider default"
  type        = string
  default     = null
}
