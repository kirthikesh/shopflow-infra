# ShopFlow infrastructure. Run `make help` to list commands.
#
# Order the first time:   make bootstrap  ->  make platform-apply  ->  make dev-apply
# End of every session:   make down        (destroys dev and platform, keeps the state account)

.DEFAULT_GOAL := help
SHELL := /bin/bash

# AzureRM 4+ needs the subscription ID explicitly; take it from your `az login`.
export ARM_SUBSCRIPTION_ID ?= $(shell az account show --query id -o tsv 2>/dev/null)

# Your public IP, so only you can reach the AKS API server while it's public.
MY_IP := $(shell curl -s --max-time 5 https://api.ipify.org)
export TF_VAR_aks_api_server_authorized_ip_ranges := ["$(MY_IP)/32"]

BACKEND    := $(CURDIR)/generated/backend.hcl
STATE_VARS := $(CURDIR)/generated/state.tfvars.json
TF_DIRS    := bootstrap platform envs/dev

.PHONY: help check bootstrap \
        platform-init platform-plan platform-apply platform-destroy \
        dev-init dev-plan dev-apply dev-destroy \
        aks-up aks-down aks-creds \
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

dev-init: check $(BACKEND) ## Initialise the dev layer
	terraform -chdir=envs/dev init -upgrade -backend-config=$(BACKEND)

dev-plan: dev-init ## Preview dev changes
	terraform -chdir=envs/dev plan -var-file=$(STATE_VARS)

dev-apply: dev-init ## Create or update the dev environment
	terraform -chdir=envs/dev apply -var-file=$(STATE_VARS)

dev-destroy: dev-init ## Destroy the dev environment
	terraform -chdir=envs/dev destroy -var-file=$(STATE_VARS)

# ---- AKS on/off (the expensive part) -----------------------------------

aks-up: dev-apply ## Create AKS and Service Bus (part of the dev layer)

aks-down: dev-init ## Delete only AKS and Service Bus; keep network, Key Vault, ACR
	terraform -chdir=envs/dev apply -var-file=$(STATE_VARS) -var aks_enabled=false

aks-creds: ## Point kubectl at the cluster (Entra ID login via kubelogin)
	@name=$$(terraform -chdir=envs/dev output -raw aks_name) && \
	rg=$$(terraform -chdir=envs/dev output -raw resource_group_name) && \
	az aks get-credentials --resource-group $$rg --name $$name --overwrite-existing && \
	kubelogin convert-kubeconfig -l azurecli && \
	kubectl get nodes

# ---- everything ----------------------------------------------------------

up: platform-apply dev-apply ## Create platform, then dev

down: dev-destroy platform-destroy ## Destroy dev, then platform (state account is kept)

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
