# Purpose
This repository is intended to be the setup of servers in my home.

# Setup

Install required Ansible collection:
```bash
ansible-galaxy collection install -r ansible/requirements.yaml
```

# Usage

## Dynamic Proxmox Inventory

The repository uses a dynamic inventory plugin to automatically discover all VMs and LXC containers from your Proxmox server.

### Setup
1. Install the required collection:
   ```bash
   ansible-galaxy collection install -r ansible/requirements.yaml
   ```
2. Ensure your 1Password CLI (`op`) is signed in and accessible

### Usage Examples

List all discovered hosts and groups:
```bash
cd ansible
op run --env-file .env -- ansible-inventory -i inventory --list
```

Run a playbook against all hosts:
```bash
cd ansible
op run --env-file .env -- ansible-playbook playbooks/update_all_packages.yaml
```

Target specific groups:
```bash
cd ansible
op run --env-file .env -- ansible-playbook --limit proxmox_tags_updateable ansible/playbooks/update_all_packages.yaml
```

## Proxmox API access

Ansible and OpenTofu each use their own API token, created once on any cluster
node (tokens live in cluster config, so there is nothing to repeat per node).
Both are created with privilege separation on, so a token holds only the ACLs
granted to it below, not root's permissions. The secret is shown once at
creation - store it straight away in the `Proxmox` 1Password item (`agb` vault)
as `ansible-api-token` / `opentofu-api-token`.

```bash
pveum user token add root@pam ansible --privsep 1
pveum user token add root@pam opentofu --privsep 1
```

The `ansible` token only needs to read (the dynamic inventory plugin lists
nodes, LXC containers and VMs), so it gets the read-only `PVEAuditor` role:
```bash
pveum acl modify / --tokens 'root@pam!ansible' --roles PVEAuditor
```
If `ansible-inventory` later reports missing guest data (e.g. QEMU guest-agent
IPs), that is the first place to look for a missing audit privilege.

The `opentofu` token's roles are listed in the next section.

## OpenTofu (`tofu/`)

The `opentofu` API token (`root@pam!opentofu`) authenticates as itself, separate
from the `root@pam!ansible` token Ansible uses, so the two tools don't share
credentials. The built-in `PVEAdmin` role isn't quite enough for what this
config does, so the token also holds one small custom role (`OpenTofu`) rather
than the built-in `Administrator` role. Both are granted at `/` (propagated):

| Role       | Privilege(s)        | Why |
|------------|---------------------|-----|
| `PVEAdmin` | (built-in)          | Baseline: create/manage LXCs, VMs, etc. |
| `OpenTofu` | `Sys.AccessNetwork` | `proxmox_download_file` (CT/VM templates) calls Proxmox's `query-url-metadata` endpoint, which needs this - not covered by `PVEAdmin` or any built-in role short of `Administrator`. |
| `OpenTofu` | `Sys.Modify`        | Setting a QEMU VM's `startup` block (boot order/delay) requires this, checked at `/` specifically - `/nodes`-scoped grants don't satisfy it. Only needed for VMs; LXC containers' `startup` block works under `PVEAdmin` alone. |

`Sys.*` privileges are only ever checked on `/` and `/nodes/<node>`, so granting
`Sys.AccessNetwork` at `/` (rather than only `/nodes`) gives the token nothing
extra on storage, VM or pool paths.

To (re)create the custom role and grant it (plus the baseline `PVEAdmin`), run
on any cluster node:
```bash
pveum role add OpenTofu -privs "Sys.AccessNetwork,Sys.Modify"
pveum acl modify / --tokens 'root@pam!opentofu' --roles PVEAdmin,OpenTofu
```

## NUT setup
```bash
cd ansible
ansible-playbook -i inventory/physical.yaml playbooks/nut.yaml
```

## Secrets
- **monuser** password is set to `secret` for Synology compatibility
- **mainuser** password is fetched from 1Password CLI using the `community.general.onepassword` lookup plugin

## Troubleshooting

### `ERROR! A worker was found in a dead state`

Known unresolved upstream issue running ansible-core on macOS with Python 3.14 ([ansible/ansible#85123](https://github.com/ansible/ansible/issues/85123)) - Homebrew's `ansible` formula currently depends on `python@3.14`, which triggers a macOS fork-safety crash in ansible-core's worker processes. Workaround: set `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` before any `ansible`/`ansible-playbook` command, e.g.:
```bash
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES op run --env-file .env -- ansible-playbook playbooks/site.yaml
```
Remove this note once ansible-core ships a fix for the Python 3.14 combination.
