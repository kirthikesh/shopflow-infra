# ShopFlow infrastructure. Run `make help` to list commands.
#
# Order the first time:   make bootstrap  ->  make platform-apply  ->  make dev-apply
# End of every session:   make down        (destroys dev and platform, keeps the state account)

.DEFAULT_GOAL := help
SHELL := /bin/bash

# AzureRM 4+ needs the subscription ID explicitly; take it from your `az login`.
export ARM_SUBSCRIPTION_ID ?= $(shell az account show --query id -o tsv 2>/dev/null)

# Your public IP: SSH to the jump box is allowed from here only.
# (The AKS API allow-list and cluster admins come from scripts/access-vars.sh.)
MY_IP := $(shell curl -s --max-time 5 https://api.ipify.org)

# Jump box: your SSH public key and the CIDR SSH is allowed from.
SSH_PUBKEY_FILE := $(firstword $(wildcard $(HOME)/.ssh/id_ed25519.pub $(HOME)/.ssh/id_rsa.pub))
export TF_VAR_admin_ip_cidrs := ["$(MY_IP)/32"]

BACKEND    := $(CURDIR)/generated/backend.hcl
STATE_VARS := $(CURDIR)/generated/state.tfvars.json
ACCESS_VARS := $(CURDIR)/generated/access.tfvars.json
DEV_VARS   := -var-file=$(STATE_VARS) -var-file=$(ACCESS_VARS)
TF_DIRS    := bootstrap platform envs/dev management

.PHONY: help check bootstrap \
        platform-init platform-plan platform-apply platform-destroy \
        dev-init dev-plan dev-apply dev-destroy \
        access-vars aks-up aks-down aks-creds \
        jumpbox-init jumpbox-up jumpbox-down jumpbox-ssh ansible \
        up down fmt validate

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-18s\033[0m %s\n", $$1, $$2}'

check: ## Check you're logged in to Azure
	@test -n "$(ARM_SUBSCRIPTION_ID)" || { echo "Not logged in. Run: az login"; exit 1; }
	@az account show --query "{subscription:name, id:id, user:user.name}" -o table

# ---- bootstrap (once) ----------------------------------------------------

bootstrap: check ## Create the Terraform state storage account (run once)
	terraform -chdir=bootstrap init -upgrade
	terraform -chdir=bootstrap apply
	@echo ""
	@echo "State account ready. Wait about a minute for the role assignment to"
	@echo "take effect, then run: make platform-apply"

$(BACKEND):
	@echo "generated/backend.hcl is missing. Run: make bootstrap"; exit 1

# ---- platform (hub, ACR, Log Analytics, budget, policy) ------------------

platform-init: check $(BACKEND) ## Initialise the platform layer
	terraform -chdir=platform init -upgrade -backend-config=$(BACKEND)

platform-plan: platform-init ## Preview platform changes
	terraform -chdir=platform plan

platform-apply: platform-init ## Create or update the platform layer
	terraform -chdir=platform apply

platform-destroy: platform-init ## Destroy the platform layer (destroy dev first)
	terraform -chdir=platform destroy

# ---- dev environment (spoke VNet, Key Vault) ----------------------------

dev-init: check $(BACKEND) access-vars ## Initialise the dev layer
	terraform -chdir=envs/dev init -upgrade -backend-config=$(BACKEND)

access-vars: ## Work out the AKS API allow-list and cluster admins (you + pipeline agent)
	@./scripts/access-vars.sh

dev-plan: dev-init ## Preview dev changes
	terraform -chdir=envs/dev plan $(DEV_VARS)

dev-apply: dev-init ## Create or update the dev environment
	terraform -chdir=envs/dev apply $(DEV_VARS)

dev-destroy: dev-init ## Destroy the dev environment
	terraform -chdir=envs/dev destroy $(DEV_VARS)

# ---- AKS on/off (the expensive part) -----------------------------------

aks-up: dev-apply ## Create AKS and Service Bus (part of the dev layer)

aks-down: dev-init ## Delete only AKS and Service Bus; keep network, Key Vault, ACR
	terraform -chdir=envs/dev apply $(DEV_VARS) -var aks_enabled=false

aks-creds: ## Point kubectl at the cluster (Entra ID login via kubelogin)
	@name=$$(terraform -chdir=envs/dev output -raw aks_name) && \
	rg=$$(terraform -chdir=envs/dev output -raw resource_group_name) && \
	az aks get-credentials --resource-group $$rg --name $$name --overwrite-existing && \
	kubelogin convert-kubeconfig -l azurecli && \
	kubectl get nodes

# ---- management: jump box + Ansible (Phase 4) ---------------------------

jumpbox-init: check $(BACKEND)
	terraform -chdir=management init -upgrade -backend-config=$(BACKEND)

jumpbox-up: jumpbox-init ## Create the jump box VM (SSH open to your IP only)
	@test -n "$(SSH_PUBKEY_FILE)" || { echo "No SSH key. Run: ssh-keygen -t ed25519"; exit 1; }
	TF_VAR_ssh_public_key="$$(cat $(SSH_PUBKEY_FILE))" \
	  terraform -chdir=management apply -var-file=$(STATE_VARS)

jumpbox-down: jumpbox-init ## Destroy the jump box VM
	TF_VAR_ssh_public_key="$$(cat $(SSH_PUBKEY_FILE))" \
	  terraform -chdir=management destroy -var-file=$(STATE_VARS)

ansible/inventory/hosts.ini: management/*.tf
	@mkdir -p ansible/inventory
	@ip=$$(terraform -chdir=management output -raw jumpbox_public_ip) && \
	user=$$(terraform -chdir=management output -raw jumpbox_admin_username) && \
	printf '[jumpbox]\njump ansible_host=%s ansible_user=%s\n' "$$ip" "$$user" > $@
	@cat $@

ansible: ## Configure the jump box with Ansible (add ADO_ORG_URL / ADO_PAT for the agent)
	@rm -f ansible/inventory/hosts.ini
	@$(MAKE) --no-print-directory ansible/inventory/hosts.ini
	cd ansible && ansible-playbook playbooks/jumpbox.yml

jumpbox-ssh: ## SSH into the jump box
	@cd ansible && ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=.known_hosts \
	  $$(terraform -chdir=../management output -raw jumpbox_admin_username)@$$(terraform -chdir=../management output -raw jumpbox_public_ip)

# ---- everything ----------------------------------------------------------

up: platform-apply dev-apply ## Create platform, then dev

down: jumpbox-down dev-destroy platform-destroy ## Destroy jump box, dev, then platform (state account is kept)

# ---- quality -------------------------------------------------------------

fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Format-check and validate every layer (no Azure access needed)
	terraform fmt -check -recursive
	@for d in $(TF_DIRS); do \
	  echo "== $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null && \
	  terraform -chdir=$$d validate || exit 1; \
	done
