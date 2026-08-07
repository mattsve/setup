# AGENTS.md

## Repository Overview

This is a personal Ansible-based infrastructure-as-code repository for managing home servers at `hem.ingenstans.se`. It provides automated provisioning, configuration, and management of:

- **Bare metal servers** (carrot, octoprint, thermiq)
- **Network mounts** (NFS, CIFS)

## Structure

```
ansible/
├── ansible.cfg           # Ansible configuration
├── inventory.yaml        # Host inventory with group vars
├── requirements.yaml     # Galaxy roles and collections
├── playbooks/
│   ├── first.yaml        # Initial server bootstrap (sudo, ansible user)
│   ├── basic.yaml        # Base configuration (users, packages)
│   ├── mounters.yaml     # Filesystem mount configuration
│   └── files/
└── roles/
```

## Inventory Groups

| Group | Purpose | Hosts |
|-------|---------|-------|
| `ungrouped` | General servers without specific roles | octoprint, thermiq |
| `mounters` | Servers requiring mount configurations | carrot |

## Key Components

### Collections

- **community.general** (5.6.0)
- **ansible.posix** (1.1.1)

## Usage Patterns

### First-time server setup
```bash
ansible-galaxy install -r requirements.yaml
ansible-playbook -i <host>, -u root --ask-pass playbooks/first.yaml
```

### Apply configuration
```bash
ansible-playbook -i inventory.yaml playbooks/basic.yaml
ansible-playbook -i inventory.yaml playbooks/mounters.yaml
```

### Target specific hosts
```bash
ansible-playbook -i ./inventory.yaml --limit carrot ./playbooks/basic.yaml
```

## Host-Specific Configuration

Configuration is defined in `inventory.yaml` using host variables:

- `mounts` - Filesystem mount points
- `packages` - Additional packages to install
- `nut_server` - Enable NUT (Network UPS Tools) server

## Constraints

- Targets Debian/Ubuntu servers
- Assumes SSH access with sudo privileges
- Uses `ansible` user for management (created by first.yaml)
- Python 3 must be available (`/usr/bin/python3`)
- Some playbooks require `become: true` (root privileges)

## Vault Integration

Sensitive values use Ansible Vault variables with fallback defaults:
- `vault_nut_monuser_password`
- `vault_nut_mainuser_password`

## Agent Guidelines

When working with this repository:

1. **Read inventory.yaml first** - Host-specific configuration lives here
2. **Respect the playbook order** - first.yaml → basic.yaml → role-specific playbooks
3. **Preserve existing structure** - Add new hosts to inventory, not new playbooks
4. **Use existing roles** - Prefer galaxy roles over custom tasks
5. **Backup before destructive changes**
6. **Test on one host first** - Use `--limit <hostname>` for changes affecting multiple hosts
