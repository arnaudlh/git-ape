# Security Analysis: deploy-20260318-054417

**Deployment:** Cheapest VM in France Central
**Date:** 2026-03-18
**Analyzed by:** AutoCloud Security Analyzer

## Security Gate: 🟢 PASSED (with advisory findings)

All 🔴 Critical and 🟠 High security checks pass. The deployment may proceed.
Advisory findings are listed below for awareness.

---

## Per-Resource Assessment

### 1. Virtual Machine (`vm-cheapvm-dev-francecentral`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Password authentication disabled | 🔴 Critical | ✅ Applied | `properties.osProfile.linuxConfiguration.disablePasswordAuthentication: true` |
| 2 | SSH key authentication configured | 🔴 Critical | ✅ Applied | `properties.osProfile.linuxConfiguration.ssh.publicKeys` array configured |
| 3 | Managed disk for OS | 🟠 High | ✅ Applied | `properties.storageProfile.osDisk.managedDisk.storageAccountType: "Standard_LRS"` |
| 4 | Encryption at rest (OS disk) | 🟡 Medium | 🔄 Platform Default | Azure SSE is enabled by default on all managed disks. Not explicitly configured in template. |
| 5 | VM extensions (guest agent) | 🟢 Low | ℹ️ Info | No extensions deployed. Azure Guest Agent is installed by default. |
| 6 | Boot diagnostics | 🟡 Medium | ⚠️ Not applied | `properties.diagnosticsProfile.bootDiagnostics` not configured. Consider enabling for troubleshooting. |

### 2. Network Security Group (`nsg-cheapvm-dev-francecentral`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | NSG associated with subnet | 🔴 Critical | ✅ Applied | VNet subnet `snet-default` references NSG via `properties.subnets[0].properties.networkSecurityGroup.id` |
| 2 | SSH restricted to specific source | 🟠 High | ⚠️ Parameterized | `sourceAddressPrefix` is set to `[parameters('allowedSshSource')]`. Default in parameters.json is `"*"` (any source). **User must restrict before production use.** |
| 3 | No unrestricted inbound rules | 🟠 High | ✅ Applied | Only port 22 (SSH) is allowed inbound. All other inbound traffic is denied by default NSG rules. |
| 4 | Outbound traffic | 🟢 Low | ℹ️ Info | Default NSG rules allow outbound. No custom outbound restrictions applied. |

### 3. Public IP Address (`pip-cheapvm-dev-francecentral`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Standard SKU | 🟡 Medium | ✅ Applied | `sku.name: "Standard"`. Standard SKU is zone-resilient and secure by default (denies inbound until NSG allows). |
| 2 | Static allocation | 🟢 Low | ✅ Applied | `properties.publicIPAllocationMethod: "Static"` |
| 3 | Internet exposure | 🟡 Medium | ℹ️ Info | VM IS internet-facing via this public IP. SSH access is controlled by NSG rules. |

### 4. Virtual Network (`vnet-cheapvm-dev-francecentral`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Address space defined | 🟢 Low | ✅ Applied | `properties.addressSpace.addressPrefixes: ["10.0.0.0/24"]` |
| 2 | Subnet with NSG | 🔴 Critical | ✅ Applied | Subnet `snet-default` has NSG association via `properties.subnets[0].properties.networkSecurityGroup` |

### 5. Resource Group (`rg-cheapvm-dev-francecentral`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Tags applied | 🟢 Low | ✅ Applied | Environment, Project, ManagedBy, CreatedDate tags set via `tags` variable |
| 2 | Region specified | 🟢 Low | ✅ Applied | `location: "[parameters('location')]"` → `francecentral` |

---

## Summary

| Severity | Total | ✅ Applied | 🔄 Default | ⚠️ Advisory | ❌ Failed |
|----------|-------|-----------|------------|-------------|----------|
| 🔴 Critical | 4 | 4 | 0 | 0 | 0 |
| 🟠 High | 3 | 2 | 0 | 1 (parameterized) | 0 |
| 🟡 Medium | 3 | 1 | 1 | 1 | 0 |
| 🟢 Low | 4 | 3 | 0 | 1 | 0 |

## Recommendations

1. **Before deploying:** Update `allowedSshSource` parameter from `"*"` to your specific IP/CIDR (e.g., `"203.0.113.50/32"`)
2. **Optional:** Enable boot diagnostics for VM troubleshooting
3. **Optional:** Consider Azure Disk Encryption for enhanced data-at-rest protection beyond platform SSE
