# Purpose
This repository is intended to be the setup of servers in my home.

# Setup

Install required Ansible collection:
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

# Usage

## Dynamic Proxmox Inventory

The repository uses a dynamic inventory plugin to automatically discover all VMs and LXC containers from your Proxmox server.

### Setup
1. Install the required collection:
   ```bash
   ansible-galaxy collection install -r ansible/requirements.yml
   ```
2. Ensure your 1Password CLI (`op`) is signed in and accessible

### Usage Examples

List all discovered hosts and groups:
```bash
op run --env-file ansible/.env -- ansible-inventory -i ansible/inventory --list
```

Run a playbook against all hosts:
```bash
op run --env-file ansible/.env -- ansible-playbook -i ansible/inventory playbooks/update_all_packages.yaml
```

Target specific groups:
```bash
op run --env-file ansible/.env -- ansible-playbook -i ansible/inventory --limit proxmox_tags_updateable ansible/playbooks/update_all_packages.yaml
```

## NUT setup
```bash
ansible-playbook -i ansible/inventory/physical.yaml ansible/playbooks/nut.yaml
```

## Secrets
- **monuser** password is set to `secret` for Synology compatibility
- **mainuser** password is fetched from 1Password CLI using the `community.general.onepassword` lookup plugin
