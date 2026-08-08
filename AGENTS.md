# AGENTS.md

## Repository Overview

This is a personal Ansible-based infrastructure-as-code repository for managing home servers at `hem.ingenstans.se`. It provides automated provisioning and configuration for:

- **Proxmox VE server** (pve1) - Primary virtualization host
- **NUT (Network UPS Tools)** - UPS monitoring and management
- **Postfix relay** - Email relay configuration for mailbox.org
- **Package updates** - System package management across all hosts

## Structure

```
ansible/
├── .env                  # Environment variables for 1Password CLI
├── ansible.cfg           # Ansible configuration
├── inventory/            # Inventory configurations
│   ├── physical.yaml     # Static inventory for physical hosts
│   ├── proxmox.yaml      # Dynamic Proxmox inventory plugin
│   └── host_vars/        # Host-specific variables
│       └── pve1.yaml     # pve1 host configuration
├── playbooks/
│   ├── nut.yaml          # NUT server configuration
│   ├── postfix_relay.yaml # Postfix relay configuration
│   └── update_all_packages.yml  # System package updates
├── requirements.yml      # Ansible collection requirements
└── roles/
    ├── nut/              # NUT role for UPS management
    │   ├── defaults/
    │   │   └── main.yaml  # Default variables
    │   ├── handlers/
    │   │   └── main.yaml  # Role handlers
    │   ├── tasks/
    │   │   └── main.yaml  # Role tasks
    │   └── templates/     # NUT configuration templates
    │       ├── nut.conf.j2
    │       ├── ups.conf.j2
    │       ├── upsd.conf.j2
    │       ├── upsd.users.j2
    │       └── upsmon.conf.j2
    └── postfix_relay/     # Postfix relay role for email forwarding
        ├── defaults/
        │   └── main.yaml  # Default variables
        ├── handlers/
        │   └── main.yaml  # Role handlers
        ├── tasks/
        │   └── main.yaml  # Role tasks
        └── templates/     # Postfix configuration templates
            ├── canonical.j2
            ├── main.cf.j2
            ├── sasl_passwd.j2
            └── sasl_smtpd.conf.j2
```

## Current Hosts

| Host | Purpose | Configuration |
|------|---------|---------------|
| `pve1` | Proxmox VE server | NUT server enabled, Postfix relay enabled, package updates |

The dynamic Proxmox inventory plugin automatically discovers all VMs and LXC containers from the Proxmox server, filtered by tags.

## Key Components

### Roles
- **nut** - Custom role for Network UPS Tools server configuration with defaults, tasks, handlers, and Jinja2 templates
- **postfix_relay** - Custom role for Postfix email relay configuration with defaults, tasks, handlers, and Jinja2 templates

### Inventory
- **physical.yaml** - Static inventory for physical servers (pve1)
- **proxmox.yaml** - Dynamic inventory using `community.proxmox.proxmox` plugin for VM/LXC discovery

## Usage Patterns

### Apply NUT configuration (physical hosts)
```bash
cd ansible
ansible-playbook -i inventory/physical.yaml playbooks/nut.yaml
```

### Apply Postfix relay configuration (physical hosts)
```bash
cd ansible
op run --env-file .env -- ansible-playbook -i inventory/physical.yaml playbooks/postfix_relay.yaml
```

### Target specific hosts
```bash
ansible-playbook -i inventory/physical.yaml --limit pve1 playbooks/nut.yaml
```

### Update all packages (using dynamic Proxmox inventory)
```bash
cd ansible
op run --env-file .env -- ansible-playbook -i inventory/proxmox.yaml playbooks/update_all_packages.yml
```

### List all discovered hosts from Proxmox
```bash
cd ansible
op run --env-file .env -- ansible-inventory -i inventory/proxmox.yaml --list
```

### Target specific groups (using Proxmox tags)
```bash
cd ansible
op run --env-file .env -- ansible-playbook -i inventory/proxmox.yaml --limit proxmox_tags_updateable playbooks/update_all_packages.yml
```

## Host-Specific Configuration

Configuration is defined in `inventory/host_vars/<hostname>.yaml` using:

- `nut_server` - Enable NUT (Network UPS Tools) server (boolean)
- `nut_monuser_password` - Monitor user password (set to `secret` for Synology compatibility)
- `nut_mainuser_password` - Main user password (fetched from 1Password CLI using `community.general.onepassword` lookup)
- `postfix_relay_enabled` - Enable Postfix relay (boolean)
- `postfix_relay_username` - Relay username (fetched from 1Password CLI using `community.general.onepassword` lookup)
- `postfix_relay_password` - Relay password (fetched from 1Password CLI using `community.general.onepassword` lookup)
- `postfix_mydomain` - Mail domain (fetched from 1Password CLI using `community.general.onepassword` lookup)

The nut role also has default variables defined in `roles/nut/defaults/main.yaml` for UPS configuration, users, and monitoring settings.
The postfix_relay role has default variables defined in `roles/postfix_relay/defaults/main.yaml` for relay host, port, TLS settings, and SMTP authentication.

## Constraints

- Targets Proxmox VE (Debian-based) servers and discovered VMs/LXC containers
- Assumes SSH access with root privileges
- Uses root user for management
- Python 3 must be available (`/usr/bin/python3`)
- Playbooks require `become: true` (root privileges)
- 1Password CLI (`op`) must be installed and configured for secrets management

## Secrets Management

- **monuser** password: Plaintext value `secret` (required for Synology compatibility)
- **mainuser** password: Fetched via 1Password CLI using the `community.general.onepassword` lookup plugin
- **postfix_relay_username**: Fetched via 1Password CLI using `community.general.onepassword` lookup
- **postfix_relay_password**: Fetched via 1Password CLI using `community.general.onepassword` lookup
- **postfix_mydomain**: Fetched via 1Password CLI using `community.general.onepassword` lookup

Required Ansible collections (defined in `ansible/requirements.yml`):
- `community.general` - For 1Password lookup plugin and other utilities
- `community.proxmox` - For Proxmox dynamic inventory plugin

Environment variables for 1Password are stored in `ansible/.env`.

## Agent Guidelines

When working with this repository:

1. **Read inventory files and host_vars first** - Host-specific configuration lives in `inventory/` and `host_vars/`
2. **Add new physical hosts to inventory/physical.yaml** - Update the static inventory for physical servers
3. **Use the Proxmox dynamic inventory for VMs/LXC** - The `proxmox.yaml` inventory plugin automatically discovers virtual machines and containers
4. **Use roles for reusable configurations** - Prefer custom roles over ad-hoc tasks
5. **Backup before destructive changes**
6. **Test on one host first** - Use `--limit <hostname>` for changes affecting multiple hosts
7. **Keep playbooks focused** - Each playbook should have a single, clear purpose
8. **Place new playbooks in ansible/playbooks/** - All Ansible playbooks belong in this directory
9. **Use 1Password for secrets** - Run commands requiring Proxmox API access or 1Password lookups with `op run --env-file ansible/.env --`
10. **Install required collections** - Run `ansible-galaxy collection install -r ansible/requirements.yml` before execution
11. **Use tag-based filtering** - The Proxmox inventory uses tags for grouping (e.g., `proxmox_tags_updateable`)
12. **Postfix relay requires 1Password secrets** - The postfix_relay playbook must be run with `op run --env-file ansible/.env --` to access mailbox credentials from 1Password
