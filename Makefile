SHELL := /bin/bash

VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip
ANSIBLE := $(VENV)/bin/ansible
ANSIBLE_PLAYBOOK := $(VENV)/bin/ansible-playbook
ANSIBLE_GALAXY := $(VENV)/bin/ansible-galaxy
ANSIBLE_INVENTORY := $(VENV)/bin/ansible-inventory
ANSIBLE_VAULT := $(VENV)/bin/ansible-vault
ANSIBLE_DOC := $(VENV)/bin/ansible-doc

SSH_KEY := $(HOME)/.ssh/cloud1-aws.pem
VAULTED_SSH_KEY := secrets/cloud1-aws.pem.vault

.PHONY: help setup apply-env allow-ssh restore-key inventory ping syntax deploy check ssh clean-local

help:
	@echo "Available commands:"
	@echo "  make setup        - Create Python venv and install Ansible requirements" 
	@echo "  make restore-key  - Decrypt SSH private key from Ansible Vault"
	@echo "  make apply-env    - Generate local Ansible files from .env"
	@echo "  make inventory    - Show Ansible inventory graph"
	@echo "  make ping         - Test Ansible SSH connection"
	@echo "  make syntax       - Run Ansible syntax check"
	@echo "  make deploy       - Deploy the WordPress stack"
	@echo "  make ssh          - SSH into the EC2 instance"
	@echo "  make clean-local  - Remove generated local files"

setup:
	python3 -m venv $(VENV)
	$(PYTHON) -m pip install --upgrade pip ansible
	$(ANSIBLE_GALAXY) collection install -r requirements.yml --force
	$(ANSIBLE_DOC) community.docker.docker_compose_v2 >/dev/null
	@echo "Ansible environment OK."

apply-env:
	./scripts/apply-env.sh

restore-key:
	@if [ ! -f "$(VAULTED_SSH_KEY)" ]; then \
		echo "Missing $(VAULTED_SSH_KEY). Copy it into secrets/ or update VAULTED_SSH_KEY in the Makefile."; \
		exit 1; \
	fi
	mkdir -p $(HOME)/.ssh
	$(ANSIBLE_VAULT) decrypt $(VAULTED_SSH_KEY) --output $(SSH_KEY)
	chmod 400 $(SSH_KEY)

inventory:
	$(ANSIBLE_INVENTORY) --graph

ping:
	$(ANSIBLE) wordpress_servers -m ping --ask-vault-pass

syntax:
	$(ANSIBLE_PLAYBOOK) site.yml --syntax-check --ask-vault-pass

deploy:
	$(ANSIBLE_PLAYBOOK) site.yml --ask-vault-pass

ssh:
	@if [ ! -f inventory/hosts.ini ]; then \
		echo "Missing inventory/hosts.ini. Run: make apply-env"; \
		exit 1; \
	fi
	@HOST=$$(awk '/ansible_host=/{for(i=1;i<=NF;i++) if($$i ~ /^ansible_host=/){split($$i,a,"="); print a[2]}}' inventory/hosts.ini); \
	ssh -i $(SSH_KEY) ubuntu@$$HOST

clean-local:
	rm -f inventory/hosts.ini
	rm -f host_vars/*.yml
	rm -f group_vars/generated.yml
