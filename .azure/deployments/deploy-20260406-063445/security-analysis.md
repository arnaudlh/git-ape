# Security Analysis: deploy-20260406-063445

**Deployment:** Key Vault with VNet Integration (Private Endpoint)
**Date:** 2026-04-06
**Analyzed by:** AutoCloud Security Analyzer

## Security Gate: 🟢 PASSED

All 🔴 Critical and 🟠 High checks pass. Advisory findings listed below for awareness.

---

## Per-Resource Assessment

### 1. Key Vault (`kv-kvvnet-dev-<uniqueString>`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Public network access disabled | 🔴 Critical | ✅ Applied | `properties.publicNetworkAccess: "Disabled"` |
| 2 | RBAC authorization enabled | 🔴 Critical | ✅ Applied | `properties.enableRbacAuthorization: true` |
| 3 | Soft delete enabled | 🔴 Critical | ✅ Applied | `properties.enableSoftDelete: true` with `softDeleteRetentionInDays: 90` |
| 4 | Purge protection enabled | 🟠 High | ✅ Applied | `properties.enablePurgeProtection: true` |
| 5 | Network ACLs default deny | 🟠 High | ✅ Applied | `properties.networkAcls.defaultAction: "Deny"` with `bypass: "AzureServices"` |
| 6 | Private endpoint connectivity | 🟠 High | ✅ Applied | Private endpoint `pep-kv-kvvnet-dev-southeastasia` with `groupIds: ["vault"]` targeting this Key Vault |
| 7 | Access policies empty (RBAC mode) | 🟡 Medium | ✅ Applied | `properties.accessPolicies: []` — correct when using RBAC authorization |
| 8 | Tenant ID set | 🟢 Low | ✅ Applied | `properties.tenantId: "[subscription().tenantId]"` |

### 2. Virtual Network (`vnet-kvvnet-dev-southeastasia`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Dedicated PE subnet | 🟠 High | ✅ Applied | Subnet `snet-pe` (10.0.1.0/24) dedicated to private endpoints, separate from workload subnet |
| 2 | NSG on default subnet | 🟠 High | ✅ Applied | `snet-default` references NSG `nsg-default-kvvnet-dev-southeastasia` via `networkSecurityGroup.id` |
| 3 | NSG on PE subnet | 🟠 High | ✅ Applied | `snet-pe` references NSG `nsg-pe-kvvnet-dev-southeastasia` via `networkSecurityGroup.id` |
| 4 | PE network policies enabled | 🟡 Medium | ✅ Applied | `snet-pe` has `privateEndpointNetworkPolicies: "NetworkSecurityGroupEnabled"` — NSG rules enforced on private endpoints |
| 5 | Sufficient address space | 🟢 Low | ✅ Applied | VNet 10.0.0.0/16 provides room for growth; PE subnet /24 supports 256 private endpoints |
| 6 | DDoS Protection | 🟡 Medium | ⚠️ Not applied | Azure DDoS Protection Plan not associated. Not required here since Key Vault endpoint is private-only with no public-facing resources. |

### 3. Private Endpoint (`pep-kv-kvvnet-dev-southeastasia`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Placed in dedicated subnet | 🟠 High | ✅ Applied | PE references `snet-pe` subnet via `properties.subnet.id` |
| 2 | Approved connection (not manual) | 🟠 High | ✅ Applied | Using `privateLinkServiceConnections` (auto-approved) instead of `manualPrivateLinkServiceConnections` |
| 3 | DNS Zone Group configured | 🟠 High | ✅ Applied | PE has `privateDnsZoneGroups/default` child resource with correct DNS zone reference to `privatelink.vaultcore.azure.net` |
| 4 | Tags applied | 🟢 Low | ✅ Applied | PE includes `tags` from parameters |

### 4. Private DNS Zone (`privatelink.vaultcore.azure.net`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Correct zone name | 🟠 High | ✅ Applied | `privatelink.vaultcore.azure.net` matches Azure documentation for Key Vault private endpoints |
| 2 | VNet link configured | 🟠 High | ✅ Applied | Zone has `virtualNetworkLinks` referencing the VNet with `registrationEnabled: false` |
| 3 | Zone Group auto-registration | 🟡 Medium | ✅ Applied | DNS Zone Group on PE auto-manages A records for private endpoint IP |

### 5. Network Security Groups

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | NSGs assigned to all subnets | 🟠 High | ✅ Applied | `nsg-default-*` on snet-default, `nsg-pe-*` on snet-pe |
| 2 | No overly permissive rules | 🟡 Medium | ✅ Applied | `securityRules: []` — no inbound/outbound allow rules. Azure default rules apply (deny inbound from internet, allow VNet-to-VNet). |
| 3 | Tags applied | 🟢 Low | ✅ Applied | Both NSGs include `tags` from parameters |

### 6. Resource Group (`rg-kvvnet-dev-southeastasia`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Tags applied | 🟢 Low | ✅ Applied | Environment, Project, ManagedBy, CreatedDate tags set via `tags` variable |
| 2 | Region specified | 🟢 Low | ✅ Applied | `location: "[parameters('location')]"` → `southeastasia` |

---

## Summary

| Severity | Total | ✅ Applied | 🔄 Default | ⚠️ Advisory | ❌ Failed |
|----------|-------|-----------|------------|-------------|----------|
| 🔴 Critical | 3 | 3 | 0 | 0 | 0 |
| 🟠 High | 12 | 12 | 0 | 0 | 0 |
| 🟡 Medium | 5 | 4 | 0 | 1 | 0 |
| 🟢 Low | 5 | 5 | 0 | 0 | 0 |

**All Critical (3/3) and High (12/12) checks pass.** Security gate: 🟢 PASSED.

## Recommendations

1. **For production:** Enable Azure DDoS Protection Plan if the VNet will have public-facing resources in the future
2. **Optional:** Add custom NSG rules to further restrict traffic patterns within the VNet (e.g., only allow specific ports from snet-default to snet-pe)
3. **Optional:** Enable Diagnostic Settings on NSGs, VNet, and Key Vault for audit logging
4. **Optional:** Consider Azure Private Link scope for monitoring resources (Log Analytics, App Insights) if added later
5. **Optional:** Enable Key Vault logging via Diagnostic Settings to a Log Analytics workspace for audit trail
