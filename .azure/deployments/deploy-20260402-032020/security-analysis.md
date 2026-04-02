# Security Analysis: deploy-20260402-032020

**Deployment:** Virtual Network with Private Endpoints (Storage + Key Vault)
**Date:** 2026-04-02
**Analyzed by:** AutoCloud Security Analyzer

## Security Gate: 🟢 PASSED

All 🔴 Critical and 🟠 High checks pass. Advisory findings listed below for awareness.

---

## Per-Resource Assessment

### 1. Storage Account (`stvnetpedev<uniqueString>`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Public network access disabled | 🔴 Critical | ✅ Applied | `properties.publicNetworkAccess: "Disabled"` |
| 2 | HTTPS-only traffic | 🔴 Critical | ✅ Applied | `properties.supportsHttpsTrafficOnly: true` |
| 3 | Minimum TLS 1.2 | 🔴 Critical | ✅ Applied | `properties.minimumTlsVersion: "TLS1_2"` |
| 4 | Shared key access disabled | 🟠 High | ✅ Applied | `properties.allowSharedKeyAccess: false` — forces Azure AD authentication |
| 5 | Blob public access disabled | 🟠 High | ✅ Applied | `properties.allowBlobPublicAccess: false` |
| 6 | Network ACLs default deny | 🟠 High | ✅ Applied | `properties.networkAcls.defaultAction: "Deny"` and `bypass: "None"` |
| 7 | Private endpoint connectivity | 🟠 High | ✅ Applied | Private endpoint `pep-blob-vnetpe-dev-southeastasia` with `groupIds: ["blob"]` targeting this storage account |
| 8 | Encryption at rest (SSE) | 🟡 Medium | 🔄 Platform Default | Azure Storage Service Encryption (SSE) with Microsoft-managed keys is automatically enabled on all storage accounts. Not explicitly configured in template. |
| 9 | Infrastructure encryption (double encryption) | 🟡 Medium | ⚠️ Not applied | `properties.encryption.requireInfrastructureEncryption` not set. Consider enabling for highly sensitive data. |
| 10 | Immutable storage | 🟢 Low | ⚠️ Not applied | Immutability policies not configured. Consider for compliance-critical data. |

### 2. Key Vault (`kv-vnetpe-dev-<uniqueString>`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Public network access disabled | 🔴 Critical | ✅ Applied | `properties.publicNetworkAccess: "Disabled"` |
| 2 | RBAC authorization enabled | 🔴 Critical | ✅ Applied | `properties.enableRbacAuthorization: true` |
| 3 | Soft delete enabled | 🔴 Critical | ✅ Applied | `properties.enableSoftDelete: true` with `softDeleteRetentionInDays: 90` |
| 4 | Purge protection enabled | 🟠 High | ✅ Applied | `properties.enablePurgeProtection: true` |
| 5 | Network ACLs default deny | 🟠 High | ✅ Applied | `properties.networkAcls.defaultAction: "Deny"` with `bypass: "AzureServices"` |
| 6 | Private endpoint connectivity | 🟠 High | ✅ Applied | Private endpoint `pep-kv-vnetpe-dev-southeastasia` with `groupIds: ["vault"]` targeting this Key Vault |
| 7 | Access policies empty (RBAC mode) | 🟡 Medium | ✅ Applied | `properties.accessPolicies: []` — correct when using RBAC authorization |
| 8 | Tenant ID set | 🟢 Low | ✅ Applied | `properties.tenantId: "[subscription().tenantId]"` |

### 3. Virtual Network (`vnet-vnetpe-dev-southeastasia`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Dedicated PE subnet | 🟠 High | ✅ Applied | Subnet `snet-pe` (10.0.1.0/24) dedicated to private endpoints, separate from workload subnet |
| 2 | NSG on default subnet | 🟠 High | ✅ Applied | `snet-default` references NSG `nsg-default-vnetpe-dev-southeastasia` via `networkSecurityGroup.id` |
| 3 | NSG on PE subnet | 🟠 High | ✅ Applied | `snet-pe` references NSG `nsg-pe-vnetpe-dev-southeastasia` via `networkSecurityGroup.id` |
| 4 | PE network policies enabled | 🟡 Medium | ✅ Applied | `snet-pe` has `privateEndpointNetworkPolicies: "NetworkSecurityGroupEnabled"` — NSG rules enforced on private endpoints |
| 5 | Sufficient address space | 🟢 Low | ✅ Applied | VNet 10.0.0.0/16 provides room for growth; PE subnet /24 supports 256 private endpoints |
| 6 | DDoS Protection | 🟡 Medium | ⚠️ Not applied | Azure DDoS Protection Plan not associated. Consider for production environments with public-facing resources. Not required here since all PaaS endpoints are private-only. |

### 4. Private Endpoints

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Placed in dedicated subnet | 🟠 High | ✅ Applied | Both PEs reference `snet-pe` subnet via `properties.subnet.id` |
| 2 | Approved connection (not manual) | 🟠 High | ✅ Applied | Using `privateLinkServiceConnections` (auto-approved) instead of `manualPrivateLinkServiceConnections` |
| 3 | DNS Zone Group configured | 🟠 High | ✅ Applied | Both PEs have `privateDnsZoneGroups/default` child resource with correct DNS zone references |
| 4 | Tags applied | 🟢 Low | ✅ Applied | Both PEs include `tags` from parameters |

### 5. Private DNS Zones

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Correct zone names | 🟠 High | ✅ Applied | `privatelink.blob.core.windows.net` and `privatelink.vaultcore.azure.net` match Azure documentation |
| 2 | VNet links configured | 🟠 High | ✅ Applied | Both zones have `virtualNetworkLinks` referencing the VNet with `registrationEnabled: false` |
| 3 | Zone Group auto-registration | 🟡 Medium | ✅ Applied | DNS Zone Groups on PEs auto-manage A records for private endpoint IPs |

### 6. Network Security Groups

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | NSGs assigned to all subnets | 🟠 High | ✅ Applied | `nsg-default-*` on snet-default, `nsg-pe-*` on snet-pe |
| 2 | No overly permissive rules | 🟡 Medium | ✅ Applied | `securityRules: []` — no inbound/outbound allow rules. Azure default rules apply (deny inbound from internet, allow VNet-to-VNet). |
| 3 | Tags applied | 🟢 Low | ✅ Applied | Both NSGs include `tags` from parameters |

### 7. Resource Group (`rg-vnetpe-dev-southeastasia`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Tags applied | 🟢 Low | ✅ Applied | Environment, Project, ManagedBy, CreatedDate tags set via `tags` variable |
| 2 | Region specified | 🟢 Low | ✅ Applied | `location: "[parameters('location')]"` → `southeastasia` |

---

## Summary

| Severity | Total | ✅ Applied | 🔄 Default | ⚠️ Advisory | ❌ Failed |
|----------|-------|-----------|------------|-------------|----------|
| 🔴 Critical | 6 | 6 | 0 | 0 | 0 |
| 🟠 High | 15 | 15 | 0 | 0 | 0 |
| 🟡 Medium | 7 | 5 | 1 | 1 | 0 |
| 🟢 Low | 5 | 5 | 0 | 0 | 0 |

**All Critical (6/6) and High (15/15) checks pass.** Security gate: 🟢 PASSED.

## Recommendations

1. **For production:** Enable Azure DDoS Protection Plan if the VNet will have public-facing resources in the future
2. **For highly sensitive data:** Enable infrastructure encryption (double encryption) on the Storage Account
3. **Optional:** Add custom NSG rules to further restrict traffic patterns within the VNet (e.g., only allow specific ports from snet-default to snet-pe)
4. **Optional:** Enable Diagnostic Settings on NSGs and VNet for network flow logging
5. **Optional:** Consider Azure Private Link scope for monitoring resources (Log Analytics, App Insights) if added later
