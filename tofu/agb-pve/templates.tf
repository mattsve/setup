# Container templates are per node (local, non-shared storage), so each
# node that hosts a container built from one needs its own download.
resource "proxmox_download_file" "debian_13_standard_pve02" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "pve02"
  url          = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
  file_name    = "debian-13-standard_13.6-1_amd64.tar.zst"

  checksum           = "4c0c27ca6ceab5ef0b84db57825a00f26157ef1854bafe97297813e1cbe8ecb8cc9c453cab6b3b0efe1ba193a50c47ece1e41d950e411b8730b835b71e9e754b"
  checksum_algorithm = "sha512"

  # Don't re-query the upstream URL's size on every refresh: the pinned
  # checksum already guarantees the right content, and a slow or dead mirror
  # shouldn't be able to hold up unrelated plans.
  overwrite = false
}
