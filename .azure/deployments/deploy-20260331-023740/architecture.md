# Architecture: Azure Kubernetes Service (AKS) Cluster

**Deployment ID:** `deploy-20260331-023740`
**Region:** East US
**Environment:** dev
**Objective:** Deploy a managed Kubernetes cluster with Azure CNI networking, Container Insights monitoring, and Azure RBAC

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
                NODE1["🖥️ Node 1<br/>Standard_D2s_v5<br/>2 vCPU · 8 GB RAM"]
                NODE2["🖥️ Node 2<br/>Standard_D2s_v5<br/>2 vCPU · 8 GB RAM"]
            end

            RBAC["🔑 Role Assignment<br/>Network Contributor<br/>kubelet → snet-aks"]
        end
    end

    Internet["☁️ Internet"] -->|"kubectl / API Server"| AKS
    AKS --> SUBNET
    AKS --> NODE1
    AKS --> NODE2
    NODE1 --> SUBNET
    NODE2 --> SUBNET
    AKS -.->|"Container Insights"| LOG
    RBAC -.->|"Network Contributor"| SUBNET

    style AKS fill:#326CE5,stroke:#1a4db5,color:#fff
    style LOG fill:#0078D4,stroke:#005a9e,color:#fff
    style SUBNET fill:#a8d5e2,stroke:#7ab5c5
    style NODE1 fill:#4a9eda,stroke:#2d7ab8,color:#fff
    style NODE2 fill:#4a9eda,stroke:#2d7ab8,color:#fff
    style RBAC fill:#e8a838,stroke:#c4891e,color:#fff
    style Internet fill:#f0f0f0,stroke:#ccc
```

## Resource Inventory

| Resource | Type | Name | SKU/Size | Est. Monthly Cost |
|----------|------|------|----------|-------------------|
| Resource Group | Microsoft.Resources/resourceGroups | rg-k8s-dev-eastus | — | Free |
| Log Analytics Workspace | Microsoft.OperationalInsights/workspaces | log-k8s-dev-eastus | PerGB2018 | ~$5.00/mo |
| Virtual Network | Microsoft.Network/virtualNetworks | vnet-k8s-dev-eastus | — | Free |
| Subnet | (child of VNet) | snet-aks | 10.0.0.0/22 | Free |
| AKS Cluster | Microsoft.ContainerService/managedClusters | aks-k8s-dev-eastus | Free tier | Free |
| Node Pool (2× Standard_D2s_v5) | (managed by AKS) | system | 2 vCPU, 8 GB RAM each | ~$140.16/mo |
| Role Assignment | Microsoft.Authorization/roleAssignments | (auto-generated GUID) | Network Contributor | Free |

## Cost Summary

| Component | Estimated Monthly Cost |
|-----------|----------------------|
| AKS Control Plane (Free tier) | Free |
| Node Pool (2× Standard_D2s_v5, Linux) | ~$140.16 |
| OS Disks (2× 128 GB P10 Managed) | ~$38.40 |
| Log Analytics (~2 GB ingestion/mo) | ~$5.00 |
| Networking (VNet, Subnet) | Free |
| **Total** | **~$183.56/mo** |

> **Note:** Prices are estimates based on East US pay-as-you-go rates. Actual costs may vary.
> To reduce cost, consider using Standard_B2s nodes (~$60/mo for 2 nodes) or enabling autoscaling with 1 min node.

## Key Configuration

- ☸️ **Kubernetes 1.30** with stable auto-upgrade channel
- 🔐 **Azure RBAC** for Kubernetes authorization (local accounts disabled)
- 🌐 **Azure CNI** networking with Azure network policy
- 📊 **Container Insights** via Log Analytics for monitoring
- 🔑 **System-assigned managed identity** (no service principal secrets)
- 🛡️ **Azure Policy** addon enabled for governance
- 🏗️ **Availability Zones** 1, 2, 3 for node pool resilience
- 🐧 **Azure Linux (Mariner)** OS for optimized container hosting

## Connecting to the Cluster

After deployment, configure `kubectl`:
```bash
az aks get-credentials --resource-group rg-k8s-dev-eastus --name aks-k8s-dev-eastus
kubectl get nodes
```

## Pre-Deployment Checklist

- [x] Region selected: East US (primary default)
- [x] Kubernetes version: 1.30 (stable)
- [x] Node size: Standard_D2s_v5 (2 vCPU, 8 GB RAM)
- [x] Node count: 2 (spread across availability zones)
- [x] Azure RBAC enabled, local accounts disabled
- [x] Container Insights configured
- [ ] Review and approve the PR to trigger deployment
