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

## OpenTofu (`tofu/`)

The `opentofu` API token (`root@pam!opentofu`) authenticates as itself, separate
from the `root@pam!ansible` token Ansible uses, so the two tools don't share
credentials. The built-in `PVEAdmin` role isn't quite enough for what this
config does, so the token also holds two narrowly-scoped custom roles rather
than the built-in `Administrator` role:

| Path     | Role            | Privilege(s)      | Why |
|----------|-----------------|--------------------|-----|
| `/`      | `PVEAdmin`      | (built-in)         | Baseline: create/manage LXCs, VMs, etc. |
| `/nodes` | `AccessNetwork` | `Sys.AccessNetwork`| `proxmox_download_file` (CT/VM templates) calls Proxmox's `query-url-metadata` endpoint, which needs this - not covered by `PVEAdmin` or any built-in role short of `Administrator`. |
| `/`      | `SysModify`     | `Sys.Modify`       | Setting a QEMU VM's `startup` block (boot order/delay) requires this, checked at `/` specifically - `/nodes`-scoped grants don't satisfy it. Only needed for VMs; LXC containers' `startup` block works under `PVEAdmin` alone. |

To (re)create the two custom roles and grant them, run on `pve1`:
```bash
pveum role add AccessNetwork -privs Sys.AccessNetwork
pveum role add SysModify -privs Sys.Modify
pveum acl modify /nodes --tokens 'root@pam!opentofu' --roles AccessNetwork
pveum acl modify / --tokens 'root@pam!opentofu' --roles SysModify
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
