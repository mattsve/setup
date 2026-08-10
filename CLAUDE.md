# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Ansible configuration for provisioning and managing home lab servers (Proxmox host and its LXC containers).

## Setup

```bash
ansible-galaxy collection install -r ansible/requirements.yaml
```

Requires the 1Password CLI (`op`) signed in — secrets are fetched via `community.general.onepassword` lookups in `group_vars`, not stored in the repo. `ansible/.env` (gitignored) holds `PROXMOX_TOKEN_SECRET`, used via `op run --env-file .env -- ...`.

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

Run a role-tagged playbook (tags: `nut`, `postfix`) — like other playbooks, this needs the Proxmox API to discover `pve1` via the dynamic inventory, even though NUT itself connects over plain SSH:
```bash
op run --env-file .env -- ansible-playbook --tags nut playbooks/nut.yaml
```

## Architecture

**One dynamic inventory covers everything:** `inventory/proxmox.yaml` (`community.proxmox.proxmox` plugin) discovers all LXC containers, QEMU VMs, and the node itself on the Proxmox host at `pve1.hem.ingenstans.se` via its API — no `filters`/`exclude_nodes` needed. The plugin auto-creates groups per type (`proxmox_all_lxc`, `proxmox_all_qemu`, `proxmox_nodes`, etc.), and containers are additionally grouped by Proxmox tags (`proxmox_tags_<tag>`). Results are cached (`.cache/`, jsonfile, 1h TTL) since inventory is regenerated from the API on every run. This means every playbook run needs `op run --env-file .env --` (for `PROXMOX_TOKEN_SECRET`), even for playbooks like `nut.yaml` that only ever connect over SSH — the API is just how the host gets discovered.

**Connection vars are scoped by group, not set unconditionally.** LXC containers connect via `community.proxmox.proxmox_pct_remote` (`pct exec`, no SSH) via `inventory/group_vars/proxmox_all_lxc.yaml`; Proxmox nodes connect over SSH as root via `inventory/group_vars/proxmox_nodes.yaml` (`ansible_host` derives from `inventory_hostname`, so it generalizes to future nodes). These live in `group_vars` rather than the dynamic inventory's `compose`, which has no clean way to set a var conditionally per host type.

**Playbooks target a role-named group instead of a boolean flag.** `inventory/groups.yaml` is a small static inventory source that exists purely to define these groups (merging into hosts discovered by the dynamic Proxmox inventory, not adding new ones):
- `postfix_relay: children: [proxmox_nodes]` — postfix relay currently applies to every Proxmox node, expressed as a child-group relationship so newly discovered nodes are included automatically, not a list that needs manual upkeep.
- `nut: hosts: [pve1]` — NUT is tied to which physical host has the USB UPS attached, which doesn't follow from any group, so it's an explicit host list.

Each playbook then just does `hosts: <role-name>` with no `when:` gate (e.g. `postfix_relay.yaml` → `hosts: postfix_relay`, `nut.yaml` → `hosts: nut`) — group membership *is* the switch, so there's one source of truth instead of a group plus a flag that could disagree. `update_all_packages.yaml` still targets `proxmox_all_lxc` directly (not a role group, since it isn't role-gated).

**Secrets live in `group_vars`, not `defaults`.** Role `defaults/main.yaml` files set non-secret defaults and reference secret variables with `| default(...)` fallbacks; actual secret values are supplied in the relevant role's `inventory/group_vars/<role>.yaml` via 1Password lookups (`op://private/...`). When adding a new secret-consuming role, follow this pattern (define its group in `groups.yaml`, put its secrets in `group_vars/<role>.yaml`) rather than hardcoding credentials or gating with a boolean var.

**Roles** (`ansible/roles/`):
- `nut` — configures Network UPS Tools (`nut-server` + `nut-monitor`) for UPS monitoring/shutdown; installs a udev rule for the USB UPS.
- `postfix_relay` — configures Postfix to relay outbound mail through an external SMTP host (`smtp.mailbox.org` by default) using SASL auth.

Both roles follow the same shape: `defaults/main.yaml` (config vars), `tasks/main.yaml` (install package → template configs, each notifying a handler → enable/start service), `handlers/main.yaml` (restart-on-change), `templates/*.j2` (config files rendered from vars).
