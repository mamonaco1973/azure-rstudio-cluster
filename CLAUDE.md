# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Validate environment before deploying
./check_env.sh

# Full 4-phase deploy (directory → servers → packer image → cluster)
./apply.sh

# Validate cluster health and print access URLs
./validate.sh

# Full teardown in reverse order (cluster → servers → directory)
./destroy.sh
```

Individual Terraform phases (when iterating on a single phase):
```bash
cd 01-directory && terraform init && terraform apply -auto-approve
cd 02-servers   && terraform init && terraform apply -var="vault_name=<vault>" -auto-approve
cd 04-cluster   && terraform init && terraform apply \
  -var="vault_name=<vault>" \
  -var="rstudio_image_name=<image>" \
  -var="ubuntu_password=<password>" \
  -var="nfs_storage_account=<storage>" \
  -auto-approve
```

Packer image build (Phase 3):
```bash
cd 03-packer
packer init .
packer build \
  -var="client_id=$ARM_CLIENT_ID" \
  -var="client_secret=$ARM_CLIENT_SECRET" \
  -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var="tenant_id=$ARM_TENANT_ID" \
  -var="resource_group=rstudio-vmss-rg" \
  rstudio_image.pkr.hcl
```

## Required Environment Variables

```
ARM_CLIENT_ID
ARM_CLIENT_SECRET
ARM_SUBSCRIPTION_ID
ARM_TENANT_ID
```

## Architecture

Four independent Terraform phases with explicit inter-phase dependencies passed as `-var` flags:

| Phase | Directory | Creates |
|-------|-----------|---------|
| 1 | `01-directory/` | VNet, NSGs, NAT Gateway, Samba 4 Mini-AD, Azure Key Vault |
| 2 | `02-servers/` | Azure Files NFS 4.1 share + private endpoint, NFS Gateway VM, Windows AD admin VM |
| 3 | `03-packer/` | Custom Ubuntu 24.04 managed image with R, RStudio Server, AD tools |
| 4 | `04-cluster/` | VMSS (Standard_D2s_v3), Application Gateway v2, autoscale policy |

**Cross-phase dependency flow:**
- Phase 1 creates the Key Vault; its name is discovered by `apply.sh` via `az keyvault list` and passed to all subsequent phases
- Phase 2 creates the NFS storage account; its name is discovered and passed to Phase 4
- Phase 3 produces a timestamped managed image (`rstudio_image_<timestamp>`); the latest is discovered and passed to Phase 4
- Phase 4 consumes vault name, image name, ubuntu password (from Key Vault), and NFS storage account name

**Credential flow:** All secrets (AD admin, demo users, VM passwords) are generated in Phase 1 and stored in Key Vault. VMs use system-assigned managed identities with `Key Vault Secrets User` RBAC to fetch credentials at boot — nothing is embedded in Terraform state or scripts.

**VMSS bootstrap:** `04-cluster/scripts/rstudio_booter.sh` is passed as cloud-init. It mounts NFS, joins the AD domain via `realm join -U Admin`, configures SSSD (short usernames, no ldap_id_mapping), and sets R library paths. Domain join uses `Admin` (not UPN format) — using `Admin@RSTUDIO.MIKECLOUD.COM` fails Kerberos pre-auth against Samba.

**NFS mounts:** Azure Files NFS 4.1 via `aznfs` helper. Mount point `/nfs` holds `home/`, `data/`, and `rlibs/`. The `/home` symlink points to `/nfs/home`. The `/nfs` root is owned by `root:rstudio-users` with mode `rwxrws---` — VMs must be in `rstudio-users` to traverse it.

**R library path hierarchy** (set in `/usr/lib/R/etc/Rprofile.site`):
1. Personal: `~/.local/share/R/...`
2. Shared: `/nfs/rlibs` (writable by `rstudio-admins` group only)
3. System: `/usr/lib/R/library`

**Bastion:** `bastion_support` variable in `01-directory/variables.tf` defaults to `false`. The `AzureBastionSubnet` is always provisioned in the VNet, but the Bastion resource itself only deploys when `bastion_support=true`.

**Autoscale:** CPU > 60% for 1 minute triggers scale-up; min 1, default 2, max 4 instances. App Gateway uses cookie affinity and probes `/auth-sign-in` every 5 seconds.

## Domain Configuration

Default domain: `rstudio.mikecloud.com` / realm `RSTUDIO.MIKECLOUD.COM` / NetBIOS `RSTUDIO`

To change the domain, override `dns_zone`, `realm`, and `netbios` variables in `01-directory/variables.tf` and `04-cluster/variables.tf`.

## Resource Groups

- `rstudio-mini-ad-rg` — Samba 4 DC VM
- `rstudio-network-rg` — VNet, NSGs, NAT Gateway, Key Vault
- `rstudio-servers-rg` — NFS storage, NFS Gateway VM, Windows AD VM
- `rstudio-vmss-rg` — VMSS, App Gateway, Packer-built images

## Destroy Order

Destroy **must** run in reverse phase order: cluster (04) → servers (02) → directory (01). The `destroy.sh` script handles this. Phase 3 (Packer images) are deleted separately via `az image delete` inside `destroy.sh` after Phase 4 teardown.

Note: `destroy.sh` targets `azurerm_private_dns_zone_virtual_network_link.file_link` first in Phase 2, then sleeps 60 seconds before the full destroy — this avoids a race condition in Azure DNS propagation.
