# Image Build Failures

Packer build failed. Here's how to figure out why.

## Check the error message

Packer usually tells you what went wrong. Common patterns:

### "AuthorizationFailed"

Your service principal doesn't have the right permissions.

```bash
# Check what role assignments exist
az role assignment list --assignee <client-id> --output table
```

Need at least Contributor on the resource group where images go.

**Fix:**
```bash
az role assignment create \
  --assignee <client-id> \
  --role Contributor \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

### "Quota exceeded"

Hit VM quota limits.

```bash
az vm list-usage --location eastus --output table
```

**Fix:** Request quota increase in Azure portal, or use a different region.

### "The resource ... was not found"

Usually means the resource group doesn't exist:

```bash
az group show --name <resource-group>
```

**Fix:** Create it
```bash
az group create --name <rg-name> --location eastus
```

### Build VM creation timeout

Azure is slow today, or the VM size isn't available.

**Fix:** Try a different region or VM size. Edit `vm_size` in variables file.

### WinRM connection failed (Windows builds)

Windows Server takes forever to boot. Try increasing timeout:

In `windows.pkr.hcl`:
```hcl
winrm_timeout = "20m"  # Was 10m
```

## Script failures

If the build starts but a script fails:

### Check which script failed

Packer output shows which provisioner step failed. Look for the script name.

### Test the script manually

SSH into an equivalent VM and run the script:

```bash
# Get an Ubuntu VM
az vm create \
  --resource-group test-rg \
  --name test-vm \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
  --size Standard_DS2_v2 \
  --admin-username azureuser \
  --generate-ssh-keys

# SSH in and test
scp scripts/linux/install-containerd.sh azureuser@<ip>:/tmp/
ssh azureuser@<ip>
chmod +x /tmp/install-containerd.sh
sudo CONTAINERD_VERSION=1.7.11 /tmp/install-containerd.sh
```

## Debugging tips

### Keep the build VM on failure

Add `-on-error=ask` to packer command. If it fails, you can SSH in and look around.

```bash
packer build -on-error=ask -var-file=variables.pkrvars.hcl .
```

### More verbose output

```bash
PACKER_LOG=1 packer build -var-file=variables.pkrvars.hcl .
```

### Check Azure activity log

Sometimes Azure itself is the problem:

```bash
az monitor activity-log list --resource-group <rg-name> --output table
```

## Recovery

### Stuck resources

If build failed partway through, Packer usually cleans up. If not:

```bash
# Find orphaned resources
az resource list --resource-group <rg-name> --output table

# Delete them
az resource delete --ids <resource-id>
```

### Corrupted image

If build "succeeded" but image doesn't work:

```bash
# Delete the bad image
az image delete --name <image-name> --resource-group <rg-name>

# Rebuild
packer build -var-file=variables.pkrvars.hcl .
```
