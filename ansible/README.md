# Purpose
This repository is intended to be the setup of servers in my home.

# Usage

## Ansible galaxy
    ansible-galaxy install -r requirements.yaml

## First playbook
    ansible-playbook -i <host>, -u root --ask-pass playbooks/first.yaml

## Ansible playbook
    ansible-playbook -i inventory.yaml playbooks/basic.yaml
    ansible-playbook -i ./inventory.yaml --limit carrot ./playbooks/basic.yaml
    ansible-playbook -i inventory.yaml playbooks/k3s.yaml

### Uninstall
    ansible-playbook -i inventory.yaml playbooks/k3s.yaml --become -e 'k3s_state=uninstalled'

