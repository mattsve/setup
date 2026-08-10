# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Ansible configuration for provisioning and managing home lab servers (Proxmox host and its LXC containers).

## Setup

```bash
ansible-galaxy collection install -r ansible/requirements.yaml
```

Requires the 1Password CLI (`op`) signed in — secrets are fetched via `community.general.onepassword` lookups in `host_vars`, not stored in the repo. `ansible/.env` (gitignored) holds `PROXMOX_TOKEN_SECRET`, used via `op run --env-file .env -- ...`.

## Commands

All commands run from the `ansible/` directory.

List discovered hosts/groups from the dynamic Proxmox inventory:
```bash
op run --env-file .env -- ansible-inventory -i inventory --list
```

Run a playbook against all hosts:
```bash
op run --env-file .env -- ansible-playbook playbooks/update_all_packages.yaml
```

Target a subset of hosts (e.g. only containers tagged `updateable`):
```bash
op run --env-file .env -- ansible-playbook --limit proxmox_tags_updateable playbooks/update_all_packages.yaml
```

Run a role-tagged playbook (tags: `nut`, `postfix`):
```bash
ansible-playbook --tags nut playbooks/nut.yaml
```

The NUT playbook targets the physical Proxmox host directly (not the dynamic inventory), since UPS hardware is attached there:
```bash
ansible-playbook -i inventory/physical.yaml playbooks/nut.yaml
```

## Architecture

**Two inventories, used for different purposes:**
- `inventory/proxmox.yaml` — dynamic inventory (`community.proxmox.proxmox` plugin) that discovers all LXC containers on the Proxmox host at `pve1.hem.ingenstans.se` via its API. Containers are grouped by Proxmox tags (`proxmox_tags_<tag>`) and connected to via `community.proxmox.proxmox_pct_remote` (i.e. `pct exec`, no SSH needed on containers). Results are cached (`.cache/`, jsonfile, 1h TTL) since inventory is regenerated from the API on every run.
- `inventory/physical.yaml` — static inventory for the bare-metal Proxmox host itself (`pve1`), used when a playbook needs to run on the hypervisor rather than a container (e.g. NUT UPS monitoring, which needs the physical USB UPS connection).

**Playbooks are thin wrappers that conditionally import a role**, gated by a `*_enabled`/`*_server` boolean default to `false`. This means a role only runs on hosts where the corresponding `host_vars` flag is explicitly set to `true` — e.g. `nut.yaml` only configures NUT on hosts with `nut_server: true` (see `inventory/host_vars/pve1.yaml`).

**Secrets live in `host_vars`, not `defaults`.** Role `defaults/main.yaml` files set non-secret defaults and reference secret variables with `| default(...)` fallbacks; actual secret values are supplied per-host in `inventory/host_vars/<host>.yaml` via 1Password lookups (`op://private/...`). When adding a new secret-consuming role, follow this pattern rather than hardcoding credentials.

**Roles** (`ansible/roles/`):
- `nut` — configures Network UPS Tools (`nut-server` + `nut-monitor`) for UPS monitoring/shutdown; installs a udev rule for the USB UPS.
- `postfix_relay` — configures Postfix to relay outbound mail through an external SMTP host (`smtp.mailbox.org` by default) using SASL auth.

Both roles follow the same shape: `defaults/main.yaml` (config vars), `tasks/main.yaml` (install package → template configs, each notifying a handler → enable/start service), `handlers/main.yaml` (restart-on-change), `templates/*.j2` (config files rendered from vars).
