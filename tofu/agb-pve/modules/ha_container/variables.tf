variable "name" {
  description = "Container hostname"
  type        = string
}

variable "vm_id" {
  description = "Cluster-wide VM/CT ID"
  type        = number
}

variable "node_name" {
  description = "Node the container is created on. HA decides where it runs afterwards (see main.tf)."
  type        = string
}

variable "template_file_id" {
  description = "Container template (vztmpl) on the creation node"
  type        = string
}

variable "bridge" {
  description = "SDN VNet (or bridge) for eth0"
  type        = string
}

variable "mac_address" {
  description = "Pinned MAC, so SLAAC's EUI-64 address stays stable across rebuilds"
  type        = string
}

variable "ipv4_address" {
  description = "Static IPv4 address in CIDR form"
  type        = string
}

variable "ipv4_gateway" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "cores" {
  type    = number
  default = 1
}

variable "memory" {
  description = "Dedicated memory in MiB"
  type        = number
  default     = 512
}

variable "swap" {
  type    = number
  default = 512
}

variable "disk_datastore" {
  type    = string
  default = "local-zfs"
}

variable "disk_size" {
  description = "Root disk size in GiB"
  type        = number
  default     = 4
}

variable "nesting" {
  description = "Needed by systemd inside an unprivileged container"
  type        = bool
  default     = true
}

variable "startup" {
  description = "Boot ordering; null for no ordering"
  type = object({
    order    = number
    up_delay = number
  })
  default = null
}

variable "firewall_rules" {
  description = "Inbound ACCEPT rules; everything else inbound is dropped. Source is optional (any)."
  type = list(object({
    proto   = string
    dport   = string
    source  = optional(string)
    comment = string
  }))
  default = []
}

variable "replicate_to" {
  description = "Nodes to replicate the root disk to (ZFS replication). Job numbers follow list order, so only append."
  type        = list(string)
}

variable "replication_schedule" {
  type    = string
  default = "*/15"
}

variable "ha_nodes" {
  description = "HA node-affinity priorities (higher = preferred), e.g. { pve02 = 2, pve01 = 1 }"
  type        = map(number)
}
