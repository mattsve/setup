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
