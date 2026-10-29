# shopflow-infra

![Terraform](https://img.shields.io/badge/Terraform-1.9+-111?style=flat-square&logo=terraform&logoColor=white)
![AzureRM](https://img.shields.io/badge/AzureRM-5.x-111?style=flat-square&logo=microsoftazure&logoColor=white)
![Region](https://img.shields.io/badge/Region-North_Europe-111?style=flat-square)
![State](https://img.shields.io/badge/State-Azure_Blob_+_Entra_ID-111?style=flat-square)
![Azure DevOps](https://img.shields.io/badge/Azure_DevOps-Pipelines-111?style=flat-square&logo=azuredevops&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-production_lint-111?style=flat-square&logo=ansible&logoColor=white)

Terraform for the Azure landing zone that runs [ShopFlow](https://github.com/kirthikesh/shopflow-app),
an event-driven microservices store. Hub-and-spoke networking, private DNS, a container registry,
centralised logging, and cost and policy guardrails, built as small reusable modules in separate,
independently deployable layers.

> **Status:** Phases 2–5 done: landing zone, AKS and Service Bus, an Ansible-managed build agent, and Azure DevOps pipelines that plan on pull requests and apply after approval. `make aks-down` / `make aks-up` switch the paid compute off and on.

---

## Architecture

```mermaid
flowchart LR
    subgraph SUB["Azure subscription · guardrails: allowed regions, project tag, monthly budget"]
        subgraph PLATFORM["rg-shopflow-platform-neu"]
            HUB["vnet-shopflow-hub · 10.0.0.0/16<br/>AzureBastionSubnet · snet-management · snet-private-endpoints"]
            ACR[(Container Registry)]
            LAW[(Log Analytics)]
            DNS["Private DNS zones<br/>privatelink.azurecr.io<br/>privatelink.vaultcore.azure.net"]
        end
        subgraph DEV["rg-shopflow-dev-neu"]
            SPOKE["vnet-shopflow-dev · 10.10.0.0/16<br/>snet-aks-nodes /20 · snet-ingress · snet-private-endpoints"]
            KV[(Key Vault)]
        end
        STATE[("rg-shopflow-tfstate-neu<br/>state storage · locked")]
    end
    HUB <-->|peering| SPOKE
    DNS -.linked.- HUB
    DNS -.linked.- SPOKE
    ACR -->|audit logs| LAW
    KV -->|audit logs| LAW
```

## Layers

Each layer has its own state file, so a change to dev can never touch shared resources.

| Layer | State | What it creates |
|---|---|---|
| `bootstrap/` | local | Storage account for remote state: Entra ID auth only, versioning, soft delete, delete lock |
| `platform/` | `platform.tfstate` | Hub VNet and NSGs, private DNS zones, ACR, Log Analytics, budget alerts, policy assignments |
| `envs/dev/` | `envs/dev.tfstate` | Spoke VNet peered to the hub, DNS links, Key Vault, AKS, and one Service Bus namespace per app environment (dev, prod). AKS and Service Bus are switchable |
| `management/` | `management.tfstate` | Jump box / pipeline agent VM in the hub, and the agent identity's Azure roles |

`envs/dev` reads the platform layer's outputs through `terraform_remote_state`, so nothing is copied by hand.

## Modules

| Module | Purpose |
|---|---|
| `hub-network` | Hub VNet, Bastion/management/private-endpoint subnets, NSGs |
| `spoke-network` | Environment VNet sized for AKS (CNI Overlay), NSGs, two-way peering to the hub |
| `private-dns` | Private DNS zones linked to any number of VNets |
| `container-registry` | ACR with admin user disabled, optional private endpoint, audit logs |
| `key-vault` | Key Vault with RBAC, optional private endpoint, audit logs |
| `log-analytics` | Workspace with retention and a daily ingestion cap |
| `budget` | Monthly budget with 50/80/100% actual and 100% forecast alerts |
| `policy-baseline` | Built-in Azure Policy: allowed locations (deny), resource group tag (audit) |
| `aks` | AKS with CNI Overlay + Cilium, Workload Identity, Entra ID RBAC (no local accounts), Container Insights, Key Vault CSI driver |
| `service-bus` | Standard namespace: `order-created` queue, `payment-events` topic, duplicate detection, dead-lettering |
| `jumpbox` | Ubuntu VM with managed identity, static IP, SSH keys only, nightly auto-shutdown |

## Run it

Prerequisites: Terraform 1.9+, Azure CLI, and an Azure subscription.

```bash
az login
make check                      # confirms which subscription you're using

make bootstrap                  # once: creates the state storage account
cp platform/terraform.tfvars.example platform/terraform.tfvars   # add your email
make platform-apply             # hub, ACR, logging, budget, policy
make dev-apply                  # dev spoke and Key Vault
```

Tear down at the end of every session. The state account is kept, so `make up` brings everything back:

```bash
make down                       # destroys dev, then platform
make up                         # recreates both
```

Other commands: `make validate` (format check and validate every layer, no Azure access needed),
`make dev-plan`, `make help`.

## Jump box and Ansible

`management/` creates a Linux VM in the hub's management subnet; `ansible/` configures it. The same VM is the
**Azure DevOps self-hosted agent**, so pipelines run inside the private network.

| Role | What it does |
|---|---|
| `common` | Package updates, base tools, timezone, unattended security upgrades |
| `hardening` | SSH: keys only, no root, `AllowUsers`, validated with `sshd -t` before reload. ufw (deny all, rate-limited SSH), fail2ban, auditd, kernel sysctl hardening |
| `devtools` | Azure CLI, Terraform, kubectl, kubelogin, Helm, Docker, from vendor-signed apt repositories |
| `ado_agent` | Dedicated `azdo` user, agent version fetched from the org's API, registered unattended, runs under systemd. The PAT is only used to register and is revoked afterwards |

```bash
make jumpbox-up        # VM with SSH open to your IP only; auto-shutdown at 22:00
make ansible           # idempotent: a second run reports changed=0
ADO_ORG_URL=... ADO_PAT=... make ansible   # also registers the agent
make jumpbox-ssh
make jumpbox-down
```

The playbook passes `ansible-lint` at the **production** profile.

## Pipeline

[`.azure-pipelines/infra.yml`](.azure-pipelines/infra.yml) runs in Azure DevOps on the jump box's agent.

```mermaid
flowchart LR
    PR([pull request]) --> V
    MAIN([push to main]) --> V
    V[Validate<br/>fmt · validate · ansible-lint<br/>Trivy IaC scan] --> P[Plan<br/>platform, then dev<br/>saved plans + summary]
    P -->|main only| A{Approval<br/>shopflow-infra}
    A --> AP[Apply platform] --> AD[Apply dev]
```

- **Pull requests only plan.** The plan for each layer appears on the run's Summary tab.
- **Apply runs the saved plan**, so what gets applied is exactly what was approved. A layer with no changes skips its apply and never asks for approval.
- **Trivy scans the Terraform.** Any HIGH or CRITICAL misconfiguration fails the build; the two accepted ones are listed with reasons in [`.trivyignore.yaml`](.trivyignore.yaml).
- **AKS on or off from the Run button.** The `aks` parameter is `keep` (default), `on` or `off`.
- **Same inputs as the laptop.** The pipeline and `make` both build the AKS allow-list and the admin list with [`scripts/access-vars.sh`](scripts/access-vars.sh), so a laptop apply and a pipeline apply never undo each other.

### How the pipeline authenticates

There is **no service principal and no secret**. The agent VM has a system-assigned managed identity,
and every job runs `az login --identity`; Terraform uses the same identity (`ARM_USE_MSI`).
Azure DevOps stores no Azure credential at all.

The `management/` layer grants that identity:

| Role | Scope | Why |
|---|---|---|
| Contributor | Subscription | Create and change resources |
| Role Based Access Control Administrator, **constrained** | Subscription | Can assign or remove only AcrPull, Network Contributor, AKS RBAC Cluster Admin and Key Vault Secrets Officer, the four roles the modules hand out. It cannot make anyone Owner, itself included |
| Resource Policy Contributor | Subscription | The policy baseline |
| Storage Blob Data Contributor | State account | Read and write Terraform state |
| AcrPush | Registry | The app pipeline pushes images |

The pipeline covers `platform/` and `envs/dev/`. It does not touch `bootstrap/` (the state account it
depends on) or `management/` (the VM it runs on).

### Set it up

1. `make jumpbox-up` applies the roles above, then `make ansible` installs Trivy, kustomize and buildx.
2. In Azure DevOps, **Pipelines → Library**: create the variable group `shopflow-infra` with
   `STATE_STORAGE_ACCOUNT`, `BUDGET_EMAIL`, `OWNER_OBJECT_ID` (`az ad signed-in-user show --query id -o tsv`)
   and `ADMIN_IP` (your public IP).
3. **Pipelines → Environments**: create `shopflow-infra` and add an **Approvals** check.
4. **Pipelines → New pipeline → GitHub**, choose this repo and the existing file `.azure-pipelines/infra.yml`.

## Cost

Defaults are chosen to keep an idle landing zone at a few euros a month.

| Resource | Default | Approx. cost |
|---|---|---|
| VNets, subnets, NSGs, peering | — | Free (peering traffic is billed per GB) |
| Container Registry | Basic | ~€5 / month |
| Private DNS zones | 2 zones | ~€1 / month |
| Log Analytics | 0.5 GB/day cap | Pay per GB ingested |
| Key Vault | Standard | Per operation, cents |
| State storage | LRS | Cents |
| Private endpoints | Off | ~€7 / month each when on |
| ACR Premium (needed for private endpoint) | Off | ~€45 / month when on |

The budget alert emails at 50%, 80% and 100% of the monthly amount, and when the forecast says it will be exceeded.

## Design decisions

- **Hub and spoke.** Shared services and future connectivity (Bastion, VPN, firewall) live once in the hub. Each environment is an isolated spoke, so dev and prod can never reach each other directly.
- **No shared keys anywhere.** The state account has access keys disabled and Terraform authenticates with Entra ID. ACR has its admin user off. Key Vault uses RBAC instead of access policies.
- **Layered state.** Bootstrap, platform and each environment have separate state files and separate blast radius. Destroying dev cannot affect the registry or the hub.
- **Private endpoints behind a flag.** The modules support them fully, with DNS zones already in place. They're off by default because they need something inside the VNet (the Phase 4 jump box or the Phase 3 cluster) to be useful, and ACR's needs the Premium SKU.
- **AzureRM 5.x.** Resource providers are registered explicitly per layer, since 5.x no longer registers them automatically.
- **Guardrails from day one.** A budget and region policy exist before any workload does.
- **The build agent is the only credential.** Pipelines authenticate as the agent VM's managed identity, so there is no secret to leak or rotate. The identity's power is limited by constrained role delegation, and every apply needs a human approval.
- **A pipeline can't destroy its own runner.** The agent VM lives in its own layer, which only a person applies.
- **Tag policy in audit mode.** Azure creates some resource groups itself (Network Watcher, the AKS node group) without our tags, so denying untagged groups would break those.

## Problems I hit, and how I fixed them

| Problem | Cause | Fix |
|---|---|---|
| `kubectl` timed out connecting to AKS | Home IP changed, and the API server only accepts the IPs on its allow-list | `az aks update --api-server-authorized-ip-ranges` with the new IP, and updated `ADMIN_IP` in the pipeline's variable group |
| First pipeline plan wanted to **delete the admin SSH rule** on the jump box | The hub NSG declared its rules inline, while the management layer adds one more as a separate resource; each platform apply would strip it | `ignore_changes = [security_rule]` on that NSG. Caught by reviewing the saved plan before approving |
| Plan wanted to replace the Key Vault role and change the budget | The pipeline's variable group held placeholder text instead of real values | Fixed the values and re-ran; the approval gate stopped the bad plan from being applied |
| App pipeline: `Bash exited with code 127` | `make` isn't in Ubuntu's cloud image, and the agent runs tests through the Makefile | Added `make` to the Ansible `devtools` role |
| Pods stuck `Pending`: **Insufficient cpu** | One 2-vCPU node was 97% reserved by AKS system pods plus ours, and the autoscaler couldn't add a node: the 4-vCPU quota for that VM family is shared with the jump box | Right-sized CPU requests (460m to 215m in total); dev rollouts replace pods one at a time (`maxSurge: 0`) so an update never needs spare room |
| Ansible: `'timezone' is undefined` | `group_vars/` sat in the project root; Ansible only loads it next to the inventory or playbook (ansible-lint doesn't catch this) | Moved it to `ansible/inventory/group_vars/` |
| Azure DevOps API returned **203** with a sign-in page | `uri` with `user: ""` silently skips Basic auth, so the PAT was never sent | Built the `Authorization: Basic` header explicitly; isolated it by testing the token with `curl` first (200) |
| Azure DevOps sign-in kept failing (404/500) | Browser session confusion with a personal Microsoft account across directories | Created the organisation from a clean Incognito session |
| `AADSTS530035: Access has been blocked by security defaults` when Terraform read state | Security Defaults require MFA, and data-plane endpoints (Blob Storage, Key Vault) each need their own MFA-backed token | Re-authenticated per resource: `az login --scope https://storage.azure.com/.default`, and the same for `https://vault.azure.net` |
| Key Vault create timed out after 12 minutes on `GetCertificateContacts` | The vault was created through ARM, but the provider's follow-up read goes to the vault's data plane, which had no valid token | Logged in with the Key Vault scope; Terraform replaced the half-created vault cleanly on the next apply |
| `Invalid count argument` on diagnostic settings | `count = workspace_id == null ? 0 : 1` depends on an ID that only exists after apply | Replaced with an explicit `enable_diagnostics` boolean, which is known at plan time |
| `private_dns_zone_name` not accepted on DNS zone links | AzureRM 5.x links zones by ID instead of name and resource group | Switched to `private_dns_zone_id`, caught by `terraform validate` before anything was deployed |
| AKS create rejected: `Standard_D2s_v5 is not allowed in your subscription` | New pay-as-you-go subscriptions are limited to certain VM SKUs per region, separate from vCPU quota | Compared the allowed-SKU list with `az vm list-usage` quotas and chose `Standard_EC2ads_v5`, the cheapest size that was both allowed and had quota. The size is a variable, so no module change was needed |
| `az vm list-usage` returned nothing | `Microsoft.Compute` wasn't registered on the subscription | Registered it, and added it to the dev layer's explicit provider list |
| `TasksOperationsNotAllowed` from `az acr build` | ACR Tasks (cloud builds) are disabled for new subscriptions | Built with `docker buildx --platform linux/amd64` on an ARM Mac and pushed with `az acr login`; the cloud build path stays in the Makefile for when it's enabled |
| Apply looked frozen with no output | A fresh subscription registers each resource provider on first use, which takes minutes | Pre-registered providers with `az provider register --wait`, and declared them explicitly in each layer |

## Repository layout

```
shopflow-infra/
├── Makefile
├── .azure-pipelines/   infra pipeline and templates
├── .trivyignore.yaml   accepted scan findings, with reasons
├── scripts/            access-vars.sh (shared by make and the pipeline)
├── ansible/            jump box / agent configuration
├── bootstrap/          remote state storage (local state)
├── platform/           shared hub layer
├── envs/
│   └── dev/            dev spoke layer
├── management/         jump box / agent VM and its roles
└── modules/
    ├── hub-network/
    ├── spoke-network/
    ├── private-dns/
    ├── container-registry/
    ├── key-vault/
    ├── log-analytics/
    ├── budget/
    ├── policy-baseline/
    ├── aks/
    ├── service-bus/
    └── jumpbox/
```

## Roadmap

- [x] Remote state with Entra ID auth
- [x] Hub-and-spoke network, private DNS, ACR, Log Analytics
- [x] Budget alerts and policy guardrails
- [x] AKS with Workload Identity, Entra ID RBAC, Cilium overlay, Container Insights (Phase 3)
- [x] Azure Service Bus Standard for the order flow (Phase 3)
- [ ] Make the AKS API fully private once the jump box exists (Phase 4)
- [x] Ansible-managed jump box and Azure DevOps self-hosted agent (Phase 4)
- [x] Azure DevOps pipeline: `plan` on pull request, approval before `apply`, managed-identity auth (Phase 5)
- [x] GitOps with Argo CD: dev and prod on one cluster, separate Service Bus per environment (Phase 6, see [shopflow-gitops](https://github.com/kirthikesh/shopflow-gitops))
- [ ] Prod spoke (`envs/prod`, 10.20.0.0/16)
