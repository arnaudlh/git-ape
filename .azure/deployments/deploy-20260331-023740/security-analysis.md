# Security Analysis: deploy-20260331-023740

**Deployment:** Azure Kubernetes Service (AKS) Cluster
**Date:** 2026-03-31
**Analyzed by:** Git-Ape Security Analyzer

## Security Gate: 🟢 PASSED

All 🔴 Critical and 🟠 High checks pass. Advisory findings listed below for awareness.

---

## Per-Resource Assessment

### 1. AKS Cluster (`aks-k8s-dev-eastus`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Managed identity (no service principal secrets) | 🔴 Critical | ✅ Applied | `identity.type: "SystemAssigned"` |
| 2 | Azure RBAC for Kubernetes | 🔴 Critical | ✅ Applied | `properties.aadProfile.enableAzureRBAC: true` and `properties.aadProfile.managed: true` |
| 3 | Local accounts disabled | 🔴 Critical | ✅ Applied | `properties.disableLocalAccounts: true` |
| 4 | Kubernetes RBAC enabled | 🔴 Critical | ✅ Applied | `properties.enableRBAC: true` |
| 5 | Network policy enforced | 🟠 High | ✅ Applied | `properties.networkProfile.networkPolicy: "azure"` |
| 6 | Azure CNI networking (not kubenet) | 🟠 High | ✅ Applied | `properties.networkProfile.networkPlugin: "azure"` |
| 7 | Azure Policy addon enabled | 🟠 High | ✅ Applied | `properties.addonProfiles.azurepolicy.enabled: true` |
| 8 | Auto-upgrade channel configured | 🟡 Medium | ✅ Applied | `properties.autoUpgradeProfile.upgradeChannel: "stable"` |
| 9 | Container Insights monitoring | 🟡 Medium | ✅ Applied | `properties.azureMonitorProfile.containerInsights.enabled: true` with Log Analytics workspace reference |
| 10 | Availability zones for node pool | 🟡 Medium | ⚠️ Not applied | `availabilityZones` not set on agent pool. Single-node dev cluster — acceptable for non-production. Add `availabilityZones: ["1","2","3"]` for production. |
| 11 | Private cluster (API server not public) | 🟡 Medium | ⚠️ Not applied | API server is publicly accessible. Consider `properties.apiServerAccessProfile.enablePrivateCluster: true` for production. Acceptable for dev environment. |
| 12 | Defender for Containers | 🟡 Medium | ⚠️ Not applied | Microsoft Defender for Containers not enabled. Consider for production environments. |
| 13 | Managed OS disk encryption | 🟡 Medium | 🔄 Platform Default | Azure SSE is enabled by default on all managed disks. Not explicitly configured in template. |
| 14 | Authorized IP ranges for API server | 🟡 Medium | ⚠️ Not applied | `properties.apiServerAccessProfile.authorizedIPRanges` not configured. API server accepts connections from any IP. Consider restricting for production. |

### 2. Virtual Network (`vnet-k8s-dev-eastus`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Dedicated subnet for AKS | 🟠 High | ✅ Applied | Subnet `snet-aks` (10.0.0.0/22) dedicated to AKS via `vnetSubnetID` reference |
| 2 | Sufficient address space | 🟢 Low | ✅ Applied | VNet 10.0.0.0/16 with /22 AKS subnet provides 1024 IPs for nodes and pods |
| 3 | No NSG on AKS subnet | 🟢 Low | ℹ️ Info | AKS manages its own NSG on the subnet. Custom NSGs can conflict with AKS-managed rules. Omitting is correct behavior. |

### 3. Log Analytics Workspace (`log-k8s-dev-eastus`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Retention period configured | 🟢 Low | ✅ Applied | `properties.retentionInDays: 30` |
| 2 | Linked to AKS cluster | 🟠 High | ✅ Applied | AKS `azureMonitorProfile.containerInsights` references workspace via `logAnalyticsWorkspaceResourceId` |

### 4. Role Assignment (Network Contributor)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Least-privilege scope | 🟠 High | ✅ Applied | Network Contributor (`4d97b98b-1d4f-4787-a291-c67834d212e7`) scoped to subnet, not resource group or subscription |
| 2 | Principal type specified | 🟢 Low | ✅ Applied | `properties.principalType: "ServicePrincipal"` prevents assignment delay |
| 3 | Deterministic GUID | 🟢 Low | ✅ Applied | Uses `guid()` function for idempotent role assignment name |

### 5. Resource Group (`rg-k8s-dev-eastus`)

| # | Check | Severity | Status | Evidence |
|---|-------|----------|--------|----------|
| 1 | Tags applied | 🟢 Low | ✅ Applied | Environment, Project, ManagedBy, CreatedDate tags set via `tags` variable |
| 2 | Region specified | 🟢 Low | ✅ Applied | `location: "[parameters('location')]"` → `eastus` |

---

## Summary

| Severity | Total | ✅ Applied | 🔄 Default | ⚠️ Advisory | ❌ Failed |
|----------|-------|-----------|------------|-------------|----------|
| 🔴 Critical | 4 | 4 | 0 | 0 | 0 |
| 🟠 High | 5 | 5 | 0 | 0 | 0 |
| 🟡 Medium | 6 | 2 | 1 | 3 | 0 |
| 🟢 Low | 6 | 5 | 0 | 1 | 0 |

## Recommendations

1. **For production:** Enable private cluster (`enablePrivateCluster: true`) to restrict API server access
2. **For production:** Add authorized IP ranges for the API server
3. **For production:** Enable Microsoft Defender for Containers
4. **Optional:** Configure Azure Disk Encryption for enhanced data-at-rest protection on node OS disks
5. **Optional:** Increase Log Analytics retention beyond 30 days for compliance requirements
