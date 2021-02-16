# Purpose
This repository is intended to be the setup of servers in my home.

# Usage

## Ansible galaxy
    ansible-galaxy install -r requirements.yaml

## Ansible playbook
    ansible-playbook -i inventory.yaml playbooks/k3s.yaml

### Uninstall
    ansible-playbook -i inventory.yaml playbooks/k3s.yaml --become -e 'k3s_state=uninstalled'