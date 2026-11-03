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

## OpenTofu (`tofu/<cluster>/`)

One directory per Proxmox cluster (currently `tofu/pve1/`), each with its own
provider, `.env`, lock file and state. Run `op run --env-file .env -- tofu plan`
from inside the cluster's directory.

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

## OPNsense Monit (hand-managed)

OPNsense is not managed by this repo (the `ansibleguy.opnsense` collection is tied to one OPNsense release), so this documents the manual setup. Monit runs on the firewall, outside the cluster, so it still alerts when a node or Pulse is down. Pulse covers detail and thresholds; Monit only checks reachability.

`os-monit` is already installed. Configure it under Services > Monit > Settings. Do the tabs in this order; Save each, then Apply.

**General Settings**
- Enabled, polling interval `120` s, start delay `120` s.
- Mail server: an external SMTP provider, not the Postfix relay on the nodes (that is inside the cluster). Mail format: `from: accepted@email.sender` (the provider must accept the sender).
- Grace time below is cycles x polling interval (120 s).

**Service Tests** (action `Alert` on all)

| Name | Condition |
|---|---|
| `pve_ping` | `failed ping for 5 cycles` |
| `pve_ui` | `failed port 8006 type tcp for 5 cycles` |
| `pve_ssh` | `failed port 22 type tcp for 5 cycles` |
| `pulse_ping` | `failed ping for 2 cycles` |
| `pulse_port` | `failed port 7655 type tcp for 2 cycles` |
| `quorum_lost` | `status != 0 for 2 cycles` |

The node grace (5 cycles = 10 min) must exceed a normal `proxmox_node_update` reboot. If `for N cycles` is rejected, use `N times within N cycles`.

**Service Settings**

| Name | Type | Address / Path | Tests |
|---|---|---|---|
| `pve01`-`pve03` | Remote Host | `10.1.10.11`-`.13` | `pve_ping`, `pve_ui`, `pve_ssh` |
| `pulse01` | Remote Host | `pulse01.server.agb.ingenstans.se` | `pulse_ping`, `pulse_port` |
| `pve_quorum` | Custom | `/usr/local/bin/pve_quorum_check.sh` | `quorum_lost` |

**Alert Settings** route by event type, so one node down emails after the grace period and two nodes down pushes immediately:
- Email: recipient is your address, events limited to connection/ICMP failures.
- Push: recipient `<user-key>@pomail.net` (Pushover email gateway), events limited to status failures. Keep the subject short, e.g. `subject: $SERVICE: $EVENT`.

**Quorum script**, `/usr/local/bin/pve_quorum_check.sh` on the firewall (`chmod +x`). Two of three nodes down means the cluster has lost quorum:
```sh
#!/bin/sh
# Exit non-zero when 2 or more of the 3 nodes are unreachable
down=0
for h in 10.1.10.11 10.1.10.12 10.1.10.13; do
  ping -c 2 -t 5 "$h" >/dev/null 2>&1 || down=$((down + 1))
done
[ "$down" -lt 2 ]
```

**Prerequisites and checks**
- The Proxmox firewall on `pulse01` is default-deny: allow ICMP and TCP 7655 from OPNsense. `pulse01` must resolve from OPNsense via `dns01`, or a false "down" fires when DNS is down.
- Test the mail path first (SMTP test button), then force failures: a bogus port test, an unused IP, and two bad IPs in the script. Confirm recovery messages arrive and the push is not silenced by Do Not Disturb.
- Export an OPNsense config backup afterwards. After a firmware upgrade, check the script and Monit entries survived.

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
