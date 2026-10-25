resource "proxmox_download_file" "debian_13_standard" {
  content_type = "vztmpl"
  datastore_id = "storage"
  node_name    = "pve1"
  url          = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
  file_name    = "debian-13-standard_13.6-1_amd64.tar.zst"

  checksum           = "4c0c27ca6ceab5ef0b84db57825a00f26157ef1854bafe97297813e1cbe8ecb8cc9c453cab6b3b0efe1ba193a50c47ece1e41d950e411b8730b835b71e9e754b"
  checksum_algorithm = "sha512"

  # Skip re-querying the URL on refresh: the pinned checksum guarantees the
  # content, and a slow mirror (cloud.debian.org once stalled plans ~2 min)
  # shouldn't hold up unrelated plans.
  overwrite = false
}

resource "proxmox_download_file" "debian_13_genericcloud" {
  content_type = "import"
  datastore_id = "storage"
  node_name    = "pve1"
  url          = "https://cloud.debian.org/images/cloud/trixie/20260810-2566/debian-13-genericcloud-amd64-20260810-2566.qcow2"
  file_name    = "debian-13-genericcloud-amd64-20260810-2566.qcow2"

  checksum           = "0ce1f1d675733027d3e17a4665cb95e1d7173bdf67fb8a87ff822ff5ee025bc2a90ecb270465ef395755e41c868b40072eb9ac493810196d9cf68f941afb93dc"
  checksum_algorithm = "sha512"

  # Same reasoning as above.
  overwrite = false
}

# The genericcloud image lacks qemu-guest-agent, but VMs set agent.enabled, so
# Tofu would block waiting for it; this installs it via cloud-init on first boot.
# Needs the "snippets" content type on the datastore
# (`pvesm set storage --content backup,import,iso,vztmpl,snippets`).
resource "proxmox_virtual_environment_file" "vm_vendor_data" {
  content_type = "snippets"
  datastore_id = "storage"
  node_name    = "pve1"

  source_raw {
    file_name = "vm-vendor-data.yaml"
    data      = <<-EOF
      #cloud-config
      runcmd:
        - apt-get update
        - apt-get install -y qemu-guest-agent
        - systemctl enable --now qemu-guest-agent
    EOF
  }
}
