# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Purpose

Ansible (`ansible/`) configures the home lab's Proxmox nodes and their guests; OpenTofu (`tofu/`) creates the guests. Tofu owns lifecycle (create/destroy LXCs/VMs), Ansible owns in-guest config. They don't overlap.

## Setup

```bash
ansible-galaxy collection install -r ansible/requirements.yaml
```

Needs the 1Password CLI (`op`) signed in. Secrets come from `community.general.onepassword` lookups in `group_vars`, never the repo. `ansible/.env` and `tofu/<cluster>/.env` are checked in on purpose: they only hold `op://` references, so a fresh clone just needs `op` signed in. Run everything via `op run --env-file .env -- ...`.

On macOS with Python 3.14, set `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` before any `ansible`/`ansible-playbook` command (avoids `A worker was found in a dead state`; see README Troubleshooting).

## Commands

Ansible, from `ansible/`. Every playbook needs the Proxmox API (inventory discovery), even ones that only use SSH:
```bash
op run --env-file .env -- ansible-inventory -i inventory --list
op run --env-file .env -- ansible-playbook playbooks/update_all_packages.yaml
op run --env-file .env -- ansible-playbook --tags nut playbooks/nut.yaml
op run --env-file .env -- ansible-playbook playbooks/site.yaml   # imports every playbook
```
Each role has a tag of the same name (`update_cluster_nodes` for the node updater). Scope with `--limit cluster_pve1` etc.

OpenTofu, from `tofu/<cluster>/`:
```bash
op run --env-file .env -- tofu plan
op run --env-file .env -- tofu apply
```

## Ansible architecture

**Inventory.** One dynamic-inventory file per Proxmox cluster, `inventory/<cluster>.proxmox.yaml` (the plugin only loads names ending in `proxmox.yaml`): `pve1` (old standalone node) and `agb-pve` (three-node cluster). They merge into one inventory, so **guest hostnames must be unique across clusters**. Each file reads its own token env var (`PROXMOX_TOKEN_SECRET_<CLUSTER>`) and puts its guests in `cluster_<name>`. Nodes are added by a different plugin code path that skips `groups`, so a new node needs a hand-written line under `cluster_<name>` in `groups.yaml`. Results are cached in `.cache/` for 1h.

**Connections** are set per group in `group_vars`: LXCs use `proxmox_pct_remote` (`pct exec`, no SSH); nodes use SSH as root, with `ansible_host` derived from `inventory_hostname` (`<name>.management.agb.ingenstans.se`, a CNAME to the `pveNN` record).

**Group membership is the switch.** `inventory/groups.yaml` defines groups that playbooks target with plain `hosts: <group>` and no `when:` gate:
- Tag aliases (`managed_updates`, `certbot`, `mosquitto`, `autologin`, `ssh`, `plex`, `caddy`, `technitium`, `pulse`) are `children: [proxmox_tags_<tag>]`. Enabling a role on a guest means tagging it in Proxmox (tags are in Tofu), with no inventory edit. New single-purpose apps should follow this.
- `postfix_relay` = `proxmox_nodes`; `unused_services` = `proxmox_all_lxc` (unconditional); `nut` = explicit host `pve1` (tied to the physical USB UPS).
- `ssh` is an escape hatch: `unused_services` disables sshd on every LXC unless the guest is tagged `ssh`.
- `timezone.yaml` is the one exception and targets `hosts: all`.
- A group must not share a name with a host (`Found both group and host with same name`), so guests have role names (`dns01`, `reverse-proxy01`, `mqtt01`, `plex01`, `pulse01`) and groups use the software name.

**Secrets live in `group_vars/<group>.yaml`**, not role `defaults` (which only reference them with `| default(...)`). A new secret-consuming role gets a group in `groups.yaml` and its secrets in the matching `group_vars` file. 1Password vaults: `agb` for `Proxmox`/`dns`, `private` for the rest.

**Role shape:** `defaults/main.yaml`, `tasks/main.yaml`, `handlers/main.yaml` (restart on change), `templates/*.j2`. Flags are derived from group membership or guest type (e.g. `mosquitto_tls_enabled`, `autologin_getty_unit`, `unused_services_keep_ssh`), not set as separate booleans. Role-specific reasoning lives in comments in the role itself. Cross-role patterns worth knowing:
- **Cert handoff:** `certbot` requests certs (Cloudflare DNS-01) and owns renewal via its own timer. Consumers (`mosquitto`, `caddy`, `technitium`) copy the cert out of `/etc/letsencrypt` (the live dir is `0700 root`) and refresh the copy via a script in `renewal-hooks/deploy/`. `certbot` never needs to know its consumers.
- **Install scripts:** `technitium` re-runs its installer every play (that is its update mechanism). `pulse` installs once only, because its updater prompts on `/dev/tty` and hangs under `pct exec`; Pulse's own timer keeps it current.
- **Technitium** (`dns01` primary, `dns02` secondary) is fully Ansible-managed through the `effectivelywild.technitium_dns` state-based modules, with `technitium_zones`/`records`/`dhcp_scopes`/`apps` supplied per host in `host_vars/dns01.yaml`. API calls run from the controller over HTTPS (`delegate_to: localhost`, port 53443), which is much faster than `pct exec` per record. The role probes that path first and falls back to localhost inside the guest (e.g. a rebuilt node whose name doesn't resolve yet). Sections are individually tagged (`technitium_records`, `technitium_install`, ...), so use `--tags`/`--skip-tags` rather than a full run. The primary owns all config and the secondary only joins the cluster. Add-only modules (blocked/allowed zones) don't remove entries.
- **`proxmox_node_update`** does a rolling `agb-pve` node update (`serial: 1`) gated on cluster health and replication state, using HA node-maintenance for reboots. On failure it deliberately leaves the node in maintenance. Guests are updated separately by `update_all_packages.yaml`.

## Network

- VLANs: 10 management (`10.1.10.0/24`), 20 storage, 30 corosync, 40 migration/replication, 50 server (`10.1.50.0/24`), 80 IoT, 100 main. OPNsense (hand-managed, not in this repo) does routing, inter-VLAN policy, RAs and the DHCP relay for VLAN 80.
- **IPv6 is SLAAC, not Tofu-managed.** Guests get EUI-64 addresses from their MAC, so **pin `mac_address` in Tofu** or the address changes. Each VLAN has a ULA `/64` off `fd01:eae3:bc39::/48` (VLAN ID in hex: 50 -> `:32::`, 10 -> `:a::`), and the ULA is the stable address. RAs carry an RDNSS pointing at `dns01`.
- **DNS:** Technitium on `dns01` serves VLAN 50 DHCP directly (static `10.1.50.2`) and VLAN 80 via relay. Other guests are DHCP-addressed and auto-register; friendly names are CNAMEs into `<host>.server.agb.ingenstans.se` in `host_vars/dns01.yaml`. Cloudflare stays authoritative for public `ingenstans.se` (the DNS-01 challenge); Technitium serves same-named internal zones (split horizon).
- **Gotcha:** a VLAN 50 client querying OPNsense DNS at any address other than `10.1.50.1` gets a reply from `10.1.50.1`, so UDP drops it as a mismatch and it looks like a timeout. `dns01`'s resolver is pinned to `10.1.50.1` for this reason.
- **dns01 firewall:** the Proxmox firewall is default-deny. DNS/DoT/DoH/DHCP are open to any source, because OPNsense decides which VLANs can reach it. The web console (53443) is the exception, restricted to VLAN 100 (IPv4 plus the main ULA `/64` as a separate rule, since sources can't mix families), because VLAN 50 traffic to `dns01` never crosses OPNsense.
- **Nodes:** `pve1` is `10.1.10.2` on `vmbr0.10`, hand-configured. The `agb-pve` nodes `pve01`-`pve03` use the same last octet (`.11`-`.13`) on every subnet. `nic0` -> `vmbr0` is cluster-only (`vmbr0.30` = corosync link0). `nic1` -> `vmbr1` is the VLAN-aware trunk (`vmbr1.10` management and corosync link1, `vmbr1.40` migration/replication, plus the guest VLANs). Node networking is never done through Tofu.

## OpenTofu

Provider `bpg/proxmox` with its own `root@pam!opentofu` token, separate from Ansible's read-only `PVEAuditor` token. The `opentofu` token holds `PVEAdmin` plus a custom `OpenTofu` role (`Sys.AccessNetwork` + `Sys.Modify`, granted at `/`) which `proxmox_download_file` and VM `startup` blocks need. Token and ACL setup commands are in README.

**One self-contained root module per cluster** (`tofu/pve1/`, `tofu/agb-pve/`) with its own provider endpoint, `.env`, lock file and local state. State is local and gitignored on purpose (single operator). `.terraform.lock.hcl` is committed. If state is lost, resources keep running but need `tofu import`.

`agb-pve/` has `sdn.tf` (VLAN zone `vlans` on `vmbr1`, VNets `server` = VLAN 50 and `storage` = VLAN 20; IDs max 8 chars), `templates.tf`, and one file per guest calling `modules/ha_container` or `modules/ha_vm` (guest + firewall + ZFS replication + HA resource + node-affinity rule). **Don't create a VNet for a VLAN a node has its own address on**: SDN would enslave the sub-interface and strip the node's address.

**HA-managed guests:** HA decides where they run, so `node_name` is only the creation node (`ignore_changes = [node_name]`, replication `target` ignored). Otherwise Tofu plans a destroy-and-recreate after a failover. Root disks set `replicate = true` (the provider defaults to false). To test failover use `ha-manager crm-command node-maintenance enable <node>`. A manual migrate to a lower-priority node is refused. `dns01`/`dns02` share a negative `resource-affinity` rule (`dns_apart`), so they use equal priorities on all nodes.

**Adopted guests:** `pve1/vm_pbs.tf` (`pbs01`) was installed by hand and imported only to document settings and show drift. Its `prevent_destroy` and disk `ignore_changes` are deliberate. Recreating it means restoring from backup. HAOS (`agb-pve/ha.tf`) has no cloud-init and is a UEFI image, and its MAC must be uppercase or the provider plans a NIC replacement.

**Moving a guest between clusters** (`qm remote-migrate` / `pct remote-migrate` to `pve01.management.agb.ingenstans.se`, with `--target-bridge server --target-storage local-zfs --delete 0`):
- Use a throwaway API token. The target needs `Sys.Incoming` on `/` via a temporary role. Read the secret with `read -rs`, single-quote the `!`, and `unset` it afterwards.
- `--target-bridge` keeps the VLAN `tag`, so re-set `net0` without it before first boot (VMs would be double-tagged). For containers repeat the full `net0`, including `ip=dhcp` and `firewall=1`.
- A VM's `cicustom` pointing at a source-only datastore aborts the migration, so delete it first and `qm set --cicustom` it back before the first plan.
- Afterwards: `tofu import` the guest (and the container's `firewall_rules`) into the target and `tofu state rm` it from the source. Run `pct set <id> --onboot 0` on the stopped source copy (same MAC and IP) until it is destroyed. If DNS is down, use the node IP plus `fingerprint=`.
