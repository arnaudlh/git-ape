# Architecture: Azure Kubernetes Service (AKS) Cluster (Cost-Optimized)

**Deployment ID:** `deploy-20260331-023740`
**Region:** East US
**Environment:** dev
**Objective:** Deploy a managed Kubernetes cluster — cost-optimized for dev/test (1× Standard_B2s node, 30 GB Standard disk)

## Architecture Diagram

```mermaid
graph TB
    subgraph "Subscription"
        subgraph "rg-k8s-dev-eastus"
            LOG["📊 log-k8s-dev-eastus<br/>Log Analytics Workspace<br/>PerGB2018 · 30-day retention"]

            subgraph "vnet-k8s-dev-eastus [10.0.0.0/16]"
                SUBNET["📡 snet-aks<br/>10.0.0.0/22 (1024 IPs)"]
            end

            AKS["☸️ aks-k8s-dev-eastus<br/>AKS Managed Cluster<br/>Kubernetes 1.30 · Free tier<br/>Azure CNI · Azure Network Policy"]

            subgraph "System Node Pool"
                NODE1["🖥️ Node 1<br/>Standard_B2s<br/>2 vCPU · 4 GB RAM<br/>30 GB Standard HDD"]
            end

            RBAC["🔑 Role Assignment<br/>Network Contributor<br/>kubelet → snet-aks"]
        end
    end

    Internet["☁️ Internet"] -->|"kubectl / API Server"| AKS
    AKS --> SUBNET
    AKS --> NODE1
    NODE1 --> SUBNET
    AKS -.->|"Container Insights"| LOG
    RBAC -.->|"Network Contributor"| SUBNET

    style AKS fill:#326CE5,stroke:#1a4db5,color:#fff
    style LOG fill:#0078D4,stroke:#005a9e,color:#fff
    style SUBNET fill:#a8d5e2,stroke:#7ab5c5
    style NODE1 fill:#4a9eda,stroke:#2d7ab8,color:#fff
    style RBAC fill:#e8a838,stroke:#c4891e,color:#fff
    style Internet fill:#f0f0f0,stroke:#ccc
```

## Resource Inventory

| Resource | Type | Name | SKU/Size | Est. Monthly Cost |
|----------|------|------|----------|-------------------|
| Resource Group | Microsoft.Resources/resourceGroups | rg-k8s-dev-eastus | — | Free |
| Log Analytics Workspace | Microsoft.OperationalInsights/workspaces | log-k8s-dev-eastus | PerGB2018 | ~$3.05/mo |
| Virtual Network | Microsoft.Network/virtualNetworks | vnet-k8s-dev-eastus | — | Free |
| Subnet | (child of VNet) | snet-aks | 10.0.0.0/22 | Free |
| AKS Cluster | Microsoft.ContainerService/managedClusters | aks-k8s-dev-eastus | Free tier | Free |
| Node Pool (1× Standard_B2s) | (managed by AKS) | system | 2 vCPU, 4 GB RAM | ~$30.37/mo |
| OS Disk (1× 30 GB Standard HDD) | (managed by AKS) | S4 Standard_LRS | 30 GB | ~$1.54/mo |
| Role Assignment | Microsoft.Authorization/roleAssignments | (auto-generated GUID) | Network Contributor | Free |

## Cost Summary

| Component | Estimated Monthly Cost |
|-----------|----------------------|
| AKS Control Plane (Free tier) | Free |
| Node Pool (1× Standard_B2s, Linux) | ~$30.37 |
| OS Disk (30 GB Standard HDD) | ~$1.54 |
| Log Analytics (~1.1 GB ingestion/mo) | ~$3.05 |
| Networking (VNet, Subnet) | Free |
| **Total** | **~$34.96/mo** |
| **Savings vs. original ($183.56/mo)** | **-$148.60/mo (81%)** |

> **Note:** Prices are estimates based on East US pay-as-you-go rates. Actual costs may vary.
> Standard_B2s is a burstable VM — suitable for dev/test. For production, use Standard_D2s_v5 + 2+ nodes + Standard tier.

## Cost Optimizations Applied

- ✅ **Burstable VM (Standard_B2s)** — $0.042/hr vs $0.096/hr for D2s_v5 (56% cheaper per node)
- ✅ **Single node** — 1 node instead of 2; no HA needed for dev
- ✅ **30 GB Standard HDD** — minimum OS disk size with Standard_LRS (not Premium)
- ✅ **No availability zones** — single node, so zone-spreading removed
- ✅ **AKS Free tier** — no control plane cost (no SLA)

## Key Configuration

- ☸️ **Kubernetes 1.30** with stable auto-upgrade channel
- 🔐 **Azure RBAC** for Kubernetes authorization (local accounts disabled)
- 🌐 **Azure CNI** networking with Azure network policy
- 📊 **Container Insights** via Log Analytics for monitoring
- 🔑 **System-assigned managed identity** (no service principal secrets)
- 🛡️ **Azure Policy** addon enabled for governance
- 🐧 **Azure Linux (Mariner)** OS for optimized container hosting

## ⚠️ Dev-Only Configuration

This configuration is **not suitable for production**:
- Single node = no HA (node failure = cluster outage)
- Standard_B2s = burstable CPU (unpredictable performance under sustained load)
- Free tier = no SLA
- No availability zones

For production: switch to 3× Standard_D2s_v5 + AKS Standard tier + availability zones (~$290/mo).

## Connecting to the Cluster

After deployment, configure `kubectl`:
```bash
az aks get-credentials --resource-group rg-k8s-dev-eastus --name aks-k8s-dev-eastus
kubectl get nodes
```

## Pre-Deployment Checklist

- [x] Region selected: East US (primary default)
- [x] Kubernetes version: 1.30 (stable)
- [x] Node size: Standard_B2s (2 vCPU, 4 GB RAM — cost-optimized for dev)
- [x] Node count: 1 (single node, dev-only)
- [x] Azure RBAC enabled, local accounts disabled
- [x] Container Insights configured
- [ ] Review and approve the PR to trigger deployment
