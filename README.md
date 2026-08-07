# Purpose
This repository is intended to be the setup of servers in my home.

# Setup

Install required Ansible collection:
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

# Usage

## NUT setup
```bash
ansible-playbook -i ansible/inventory.yaml ansible/playbooks/nut.yaml
```

## Secrets
- **monuser** password is set to `secret` for Synology compatibility
- **mainuser** password is fetched from 1Password CLI using the `community.general.onepassword` lookup plugin
