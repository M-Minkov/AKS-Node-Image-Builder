# Local Setup

How to run builds from your machine. Tested on Windows 10/11.

## Prerequisites

1. **Packer** - [Download here](https://developer.hashicorp.com/packer/downloads)
2. **Azure CLI** - [Download here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows)
3. **Make** (optional) - Install via `choco install make` or just run packer commands directly

Verify everything's installed:

```powershell
packer --version   # should be 1.9+
az --version       # should be 2.50+
```

## Azure setup

### Option 1: Service Principal (recommended for local dev)

Create one:

```powershell
az login
az account set --subscription "Your Subscription Name"

# Create SP with Contributor role
az ad sp create-for-rbac `
  --name "packer-aks-images" `
  --role Contributor `
  --scopes /subscriptions/<your-subscription-id> `
  --query "{client_id: appId, client_secret: password, tenant_id: tenant}"
```

Save the output - you'll need those values.

### Option 2: Azure CLI auth

If you're just testing locally, you can skip the SP and let Packer use your CLI session:

```powershell
az login
```

Then set `use_azure_cli_auth = true` in your variables file.

## Configure variables

```powershell
cd packer
copy variables.pkrvars.hcl.example variables.pkrvars.hcl
```

Edit `variables.pkrvars.hcl`:

```hcl
# Required
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
resource_group  = "rg-aks-images"
location        = "eastus"

# Auth - pick one:
# Option 1: Service Principal
client_id       = "from sp create output"
client_secret   = "from sp create output"  
tenant_id       = "from sp create output"

# Option 2: CLI auth (comment out the above)
# use_azure_cli_auth = true

# Image settings
k8s_version        = "1.29"
containerd_version = "1.7.11"
```

## Create resource group

Images need somewhere to live:

```powershell
az group create --name rg-aks-images --location eastus
```

## Build

Initialize packer plugins first:

```powershell
cd packer
packer init aks-ubuntu.pkr.hcl
```

Then build:

```powershell
# Validate Ubuntu template
packer validate "-var-file=variables.pkrvars.hcl" "aks-ubuntu.pkr.hcl"

# Validate Windows template
packer validate "-var-file=variables.pkrvars.hcl" "aks-windows.pkr.hcl"

# Build Ubuntu image
packer build "-var-file=variables.pkrvars.hcl" "aks-ubuntu.pkr.hcl"

# Build Windows image
packer build "-var-file=variables.pkrvars.hcl" "aks-windows.pkr.hcl"

# Build Ubuntu with GPU drivers
packer build "-var-file=variables.pkrvars.hcl" -var="enable_gpu=true" "aks-ubuntu.pkr.hcl"
```

Or if you have make:

```powershell
make init
make build-ubuntu
```

## Build times

Rough estimates:

| Image | Time |
|-------|------|
| Ubuntu | ~15-20 min |
| Ubuntu + GPU | ~25-30 min |
| Windows | ~30-40 min |

Windows takes longer because Windows.

## Cost

Each build spins up a temporary VM (Standard_DS2_v2 by default). Expect ~$0.50-1.00 per build depending on your region.

## Clean up

Packer cleans up the build VM automatically. To delete old images:

```powershell
az image list --resource-group rg-aks-images --output table
az image delete --name <old-image-name> --resource-group rg-aks-images
```
