# Security Analysis: deploy-20260407-020000

**Deployment:** Storage Account with Customer-Managed Keys (CMK)
**Date:** 2026-04-07
**Analyzed by:** Git-Ape Security Analyzer

## Security Gate: 🟢 PASSED

All 🔴 Critical and 🟠 High checks pass. Deployment may proceed.

---

## Per-Resource Assessment

### 1. Storage Account (`ststcmkdev<uniqueString>`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | HTTPS-only traffic | 🔴 Critical | ✅ Applied | `properties.supportsHttpsTrafficOnly: true` |
| 2 | Minimum TLS 1.2 | 🔴 Critical | ✅ Applied | `properties.minimumTlsVersion: "TLS1_2"` |
| 3 | Customer-managed key encryption | 🔴 Critical | ✅ Applied | `properties.encryption.keySource: "Microsoft.Keyvault"` with `keyvaultproperties.keyvaulturi` and `keyvaultproperties.keyname` configured |
| 4 | Encryption identity configured | 🔴 Critical | ✅ Applied | `properties.encryption.identity.userAssignedIdentity` set to managed identity resource ID |
| 5 | All storage services encrypted | 🔴 Critical | ✅ Applied | `properties.encryption.services.blob.enabled: true`, `.file.enabled: true`, `.table.enabled: true`, `.queue.enabled: true` — all four services encrypted with Account key type |
| 6 | Shared key access disabled | 🟠 High | ✅ Applied | `properties.allowSharedKeyAccess: false` — forces Azure AD authentication |
| 7 | Blob public access disabled | 🟠 High | ✅ Applied | `properties.allowBlobPublicAccess: false` |
| 8 | Network ACLs default deny | 🟠 High | ✅ Applied | `properties.networkAcls.defaultAction: "Deny"` with `bypass: "AzureServices"` |
| 9 | User-Assigned Managed Identity | 🟠 High | ✅ Applied | `identity.type: "UserAssigned"` with `userAssignedIdentities` containing the identity resource ID |
| 10 | Infrastructure encryption (double encryption) | 🟡 Medium | ✅ Applied | `properties.encryption.requireInfrastructureEncryption: true` — data encrypted with two different algorithms |
| 11 | Encryption at rest (SSE) | 🟡 Medium | 🔄 Platform Default | Azure Storage Service Encryption (SSE) is automatically enabled on all storage accounts. CMK overrides the default Microsoft-managed key. |

### 2. Key Vault (`kv-stcmk-dev-<uniqueString>`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | RBAC authorization enabled | 🔴 Critical | ✅ Applied | `properties.enableRbacAuthorization: true` |
| 2 | Soft delete enabled | 🔴 Critical | ✅ Applied | `properties.enableSoftDelete: true` with `softDeleteRetentionInDays: 90` |
| 3 | Purge protection enabled | 🔴 Critical | ✅ Applied | `properties.enablePurgeProtection: true` — required for CMK scenarios to prevent accidental key deletion |
| 4 | Network ACLs bypass Azure Services | 🟠 High | ✅ Applied | `properties.networkAcls.bypass: "AzureServices"` — allows Storage Account to access Key Vault for CMK operations |
| 5 | Access policies empty (RBAC mode) | 🟡 Medium | ✅ Applied | No `accessPolicies` array configured — correct when using RBAC authorization |
| 6 | Tenant ID set | 🟢 Low | ✅ Applied | `properties.tenantId: "[subscription().tenantId]"` |
| 7 | Public network access | 🟡 Medium | ⚠️ Not applied | `publicNetworkAccess` not explicitly set to `"Disabled"`. Key Vault is accessible from public networks with `networkAcls.defaultAction: "Allow"`. Consider restricting to private endpoints for production. Acceptable for dev as the managed identity accesses KV through Azure backbone. |

### 3. Key Vault Key (`cmk-storage`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Key type RSA | 🟠 High | ✅ Applied | `properties.kty: "RSA"` |
| 2 | Key size 2048+ | 🟠 High | ✅ Applied | `properties.keySize: 2048` — minimum recommended size for CMK |
| 3 | Key operations restricted | 🟠 High | ✅ Applied | `properties.keyOps: ["wrapKey", "unwrapKey"]` — limited to encryption operations only |
| 4 | Auto-rotation | 🟡 Medium | ⚠️ Not applied | Key rotation policy not configured. Consider adding `rotationPolicy` for automatic key rotation in production. |

### 4. User-Assigned Managed Identity (`id-stcmk-dev-southeastasia`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Managed Identity (no credentials) | 🔴 Critical | ✅ Applied | `Microsoft.ManagedIdentity/userAssignedIdentities` — no secrets or certificates to manage |
| 2 | Tags applied | 🟢 Low | ✅ Applied | Tags include Environment, Project, ManagedBy, CreatedDate |

### 5. RBAC Role Assignment

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Least-privilege role | 🔴 Critical | ✅ Applied | Role: `Key Vault Crypto Service Encryption User` (e147488a-f6f5-4113-8e2d-b22465e65bf6) — grants only wrapKey/unwrapKey on keys, nothing else |
| 2 | Scoped to Key Vault | 🟠 High | ✅ Applied | Role assignment scoped to `Microsoft.KeyVault/vaults/{kvName}` — not subscription or resource group wide |
| 3 | Principal type set | 🟠 High | ✅ Applied | `properties.principalType: "ServicePrincipal"` — prevents assignment to wrong identity type |
| 4 | Deterministic name | 🟢 Low | ✅ Applied | Role assignment name generated via `guid(kvId, identityId, roleId)` — idempotent on redeployment |

### 6. Resource Group (`rg-stcmk-dev-southeastasia`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Tags applied | 🟢 Low | ✅ Applied | Environment, Project, ManagedBy, CreatedDate tags set via `tags` variable |
| 2 | Region specified | 🟢 Low | ✅ Applied | `location: "[parameters('location')]"` → `southeastasia` |

---

## Summary

| Severity | Total | ✅ Applied | 🔄 Default | ⚠️ Advisory | ❌ Failed |
|----------|-------|-----------|------------|-------------|----------|
| 🔴 Critical | 9 | 9 | 0 | 0 | 0 |
| 🟠 High | 9 | 9 | 0 | 0 | 0 |
| 🟡 Medium | 4 | 2 | 1 | 1 | 0 |
| 🟢 Low | 4 | 4 | 0 | 0 | 0 |

**All Critical (9/9) and High (9/9) checks pass.** Security gate: 🟢 PASSED.

## Recommendations

1. **For production:** Restrict Key Vault public network access by setting `publicNetworkAccess: "Disabled"` and using private endpoints
2. **For production:** Add a key rotation policy on the CMK key for automatic rotation (e.g., every 90 days)
3. **Optional:** Enable Key Vault diagnostic settings for audit logging of key operations
4. **Optional:** Add Azure Policy assignments to enforce CMK encryption on all storage accounts in the subscription
5. **Optional:** Consider HSM-protected keys (`kty: "RSA-HSM"`) for higher security assurance in production
