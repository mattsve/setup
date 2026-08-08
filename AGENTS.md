# AGENTS.md

## Repository Overview

This is a personal Ansible-based infrastructure-as-code repository for managing home servers at `hem.ingenstans.se`. It provides automated provisioning and configuration for:

- **Proxmox VE server** (pve1) - Primary virtualization host
- **NUT (Network UPS Tools)** - UPS monitoring and management

## Structure

```
ansible/
├── ansible.cfg           # Ansible configuration
├── inventory.yaml        # Host inventory
├── host_vars/            # Host-specific variables
│   └── pve1.yaml         # pve1 host configuration
├── playbooks/
│   └── nut.yaml          # NUT server configuration
└── roles/
    └── nut/              # NUT role for UPS management
        ├── tasks/
        │   └── main.yaml
        └── templates/     # NUT configuration templates
```

## Current Hosts

| Host | Purpose | Configuration |
|------|---------|---------------|
| `pve1` | Proxmox VE server | NUT server enabled |

## Key Components

### Roles
- **nut** - Custom role for Network UPS Tools server configuration

## Usage Patterns

### Apply NUT configuration
```bash
ansible-playbook -i inventory.yaml playbooks/nut.yaml
```

### Target specific hosts
```bash
ansible-playbook -i inventory.yaml --limit pve1 playbooks/nut.yaml
```

## Host-Specific Configuration

Configuration is defined in `host_vars/<hostname>.yaml` using:

- `nut_server` - Enable NUT (Network UPS Tools) server (boolean)
- `nut_monuser_password` - Monitor user password (set to `secret` for Synology compatibility)
- `nut_mainuser_password` - Main user password (fetched from 1Password CLI)

## Constraints

- Targets Proxmox VE (Debian-based) servers
- Assumes SSH access with root privileges
- Uses root user for management
- Python 3 must be available (`/usr/bin/python3`)
- Playbooks require `become: true` (root privileges)

## Secrets Management

- **monuser** password: Plaintext value `secret` (required for Synology compatibility)
- **mainuser** password: Fetched via 1Password CLI using the `community.general.onepassword` lookup plugin

Required Ansible collection: `community.general` (defined in `ansible/requirements.yml`)

## Agent Guidelines

When working with this repository:

1. **Read inventory.yaml and host_vars first** - Host-specific configuration lives here
2. **Add new hosts to inventory** - Update inventory.yaml and create corresponding host_vars files
3. **Use roles for reusable configurations** - Prefer custom roles over ad-hoc tasks
4. **Backup before destructive changes**
5. **Test on one host first** - Use `--limit <hostname>` for changes affecting multiple hosts
6. **Keep playbooks focused** - Each playbook should have a single, clear purpose
7. **Place new playbooks in ansible/playbooks/** - All Ansible playbooks belong in this directory
8. **Use 1Password for secrets** - Run commands requiring Proxmox API access with `op run --env-file ansible/.env --`
