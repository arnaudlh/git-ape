---
name: azure-policy-advisor
description: "Assess Azure Policy compliance for ARM template resources. Recommends built-in policy definitions and compliance initiatives using Microsoft Learn documentation. Produces per-resource policy recommendations with implementation options."
argument-hint: "ARM template JSON or resource types to assess, and optionally a compliance framework (CIS, NIST, general)"
user-invocable: true
---

# Azure Policy Advisor

Recommend Azure Policy assignments for ARM template resources using current Microsoft Learn documentation. Produces per-resource policy recommendations with severity ratings, built-in definition IDs, and ready-to-use implementation options.

## When to Use

- After template generation — recommend policies that complement deployed resources
- Compliance audit — assess resources against CIS, NIST, or general best practices
- During onboarding — recommend baseline policies for a new subscription
- When user asks "what policies should we enforce?" or "are we compliant with X?"

## Procedure

### 1. Load Compliance Context and Identify Resources

Read compliance preferences from the `## Compliance & Azure Policy` section in `copilot-instructions.md` (available automatically in conversation context). Extract:

- **Compliance frameworks** (e.g., CIS Azure Foundations v3.0, NIST SP 800-53 Rev 5, general best practices)
- **Enforcement mode** (Audit or Deny)
- **Policy categories** (identity, networking, storage, compute, monitoring, tagging)

If no compliance section exists in copilot-instructions.md, ask the user:

```
Which compliance approach should I assess against?
1. General Azure best practices (recommended)
2. CIS Azure Foundations v3.0
3. NIST SP 800-53 Rev 5
4. Custom — tell me what to check
```

Then parse the ARM template (if provided) to extract all resource types:

```markdown
Extract for each resource:
- Resource type (e.g., Microsoft.Storage/storageAccounts)
- Resource name
- Current security-relevant properties (cross-reference with security-analyzer output if available)
```

### 2. Research Applicable Built-in Policies via Microsoft Learn

**For EACH resource type**, query Microsoft Learn for current built-in policy definitions:

```
Tool: microsoft_docs_search
Query: "Azure Policy built-in {resource-type-category}"

Examples:
- "Azure Policy built-in Storage Accounts"
- "Azure Policy built-in App Service Function Apps"
- "Azure Policy built-in SQL Server database"
- "Azure Policy built-in Key Vault"
- "Azure Policy built-in Kubernetes AKS"
- "Azure Policy built-in virtual machines compute"
- "Azure Policy built-in network security"
- "Azure Policy built-in monitoring diagnostic settings"
```

For **compliance frameworks**, also query:

```
Tool: microsoft_docs_search
Query: "Azure Policy built-in initiative {framework-name}"

Examples:
- "Azure Policy built-in initiative CIS Azure Foundations"
- "Azure Policy built-in initiative NIST SP 800-53"
- "Azure Policy regulatory compliance initiative"
```

When search results reference a high-value page, use `microsoft_docs_fetch` to retrieve the full content:

```
Tool: microsoft_docs_fetch
URL: https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies

Use this to get the complete list of built-in policies organized by category (Storage, App Service, SQL, Key Vault, Network, Monitoring, etc.)
```

Key Microsoft Learn reference pages:

| Content | URL |
|---------|-----|
| All built-in policies | `https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies` |
| Built-in initiatives | `https://learn.microsoft.com/azure/governance/policy/samples/built-in-initiatives` |
| Regulatory compliance | `https://learn.microsoft.com/azure/governance/policy/concepts/regulatory-compliance` |
| Policy assignment via ARM | `https://learn.microsoft.com/azure/governance/policy/assign-policy-template` |
| Policy effects reference | `https://learn.microsoft.com/azure/governance/policy/concepts/effect-basics` |

### 3. Classify and Prioritize Recommendations

Group recommended policies into severity tiers based on the enforcement mode from compliance context:

| Tier | Effect (Audit mode) | Effect (Deny mode) | When to Use |
|------|--------------------|--------------------|-------------|
| 🔴 **Critical** | Audit | Deny | Prevents insecure deployments: public storage access, missing HTTPS, no encryption |
| 🟠 **High** | Audit | Deny | Strong security posture: managed identity required, TLS 1.2, AAD-only auth |
| 🟡 **Medium** | Audit | Audit | Visibility and tracking: tag compliance, diagnostic settings, allowed locations |
| 🔵 **Low** | AuditIfNotExists | DeployIfNotExists | Auto-remediation: deploy diagnostic settings, enable monitoring |

**Per resource type, prioritize these policy categories:**

**Storage Accounts:**
1. 🔴 Require secure transfer (HTTPS)
2. 🔴 Disable public blob access
3. 🟠 Disable shared key access
4. 🟠 Require minimum TLS 1.2
5. 🟡 Require private endpoints (production)
6. 🟡 Enable soft delete for blobs and containers
7. 🔵 Deploy diagnostic settings

**App Service / Function Apps:**
1. 🔴 Require HTTPS only
2. 🔴 Require managed identity
3. 🟠 Require minimum TLS 1.2
4. 🟠 Disable FTP / require FTPS only
5. 🟡 Disable public network access (production)
6. 🔵 Enable resource logs

**SQL Servers / Databases:**
1. 🔴 Require AAD-only authentication
2. 🔴 Enable transparent data encryption
3. 🟠 Enable auditing
4. 🟠 Enable Advanced Threat Protection
5. 🟡 Require private endpoints (production)
6. 🔵 Deploy diagnostic settings

**Key Vault:**
1. 🔴 Enable RBAC authorization
2. 🔴 Enable soft delete and purge protection
3. 🟠 Disable public network access (production)
4. 🟡 Require private endpoints
5. 🔵 Deploy diagnostic settings for audit events

**Compute / VMs:**
1. 🔴 Require managed disks
2. 🟠 Require managed identity
3. 🟡 Restrict allowed VM SKUs
4. 🟡 Require approved extensions only
5. 🔵 Deploy monitoring agent

**AKS / Kubernetes:**
1. 🔴 Require managed identity
2. 🔴 Disable local accounts
3. 🟠 Require Azure Policy add-on
4. 🟠 Require network policy
5. 🟡 Require authorized IP ranges for API server
6. 🔵 Enable Container Insights

**Networking:**
1. 🟠 Require NSG flow logs
2. 🟡 Enable Network Watcher
3. 🟡 Restrict allowed locations
4. 🔵 Deploy DDoS protection (production)

**General / Cross-cutting:**
1. 🟡 Require tags on resources (ManagedBy, Environment, Project)
2. 🟡 Restrict allowed locations
3. 🔵 Require resource group tags inheritance

For each recommendation, cross-reference with the ARM template to determine:
- ✅ **Already compliant** — template already configures the property the policy would enforce
- ⚠️ **Not assigned** — policy not active, template may or may not comply
- 🔄 **Complementary** — policy would add enforcement on top of existing template config

### 4. Generate Policy Recommendations Report

Present findings in a per-resource-type table:

```markdown
## Azure Policy Compliance Assessment

**Scope:** {subscription or resource group}
**Deployment:** {deployment ID or "general subscription audit"}
**Compliance Framework:** {framework from copilot-instructions.md or user input}
**Enforcement Mode:** {Audit or Deny}

### Summary

| Category | Recommended | Already Compliant | Gap |
|----------|-------------|-------------------|-----|
| Storage | 7 | 3 | 4 |
| App Service | 6 | 2 | 4 |
| Total | 13 | 5 | 8 |

### Recommended Policies by Resource Type

#### Storage Accounts
| # | Policy | Effect | Severity | Built-in ID | Template Status | Source |
|---|--------|--------|----------|-------------|-----------------|--------|
| 1 | Secure transfer required | Deny | 🔴 Critical | 404c3081-... | ✅ Compliant | [MS Learn]({url}) |
| 2 | Disable shared key access | Audit | 🟠 High | ... | ⚠️ Not enforced | [MS Learn]({url}) |

#### {Next Resource Type}
...
```

**If a compliance framework was selected**, also recommend the built-in initiative:

```markdown
### Recommended Compliance Initiative

| Initiative | Policies | Version | Built-in ID |
|------------|----------|---------|-------------|
| CIS Azure Foundations v3.0.0 | 53 | 1.3.0 | {id from MS Learn} |

Assigning this initiative covers {N} of the {M} individual policies recommended above.
Remaining {M-N} policies need individual assignment.
```

### 5. Provide Implementation Options

For recommended policies, provide ready-to-use implementation:

**Option A: Azure CLI (quickest for individual policies)**

```bash
# Assign a built-in policy at subscription scope
az policy assignment create \
  --name "{policy-short-name}" \
  --display-name "{policy display name}" \
  --policy "{built-in-definition-id}" \
  --scope "/subscriptions/{subscription-id}" \
  --params '{}' \
  --enforcement-mode Default

# Assign a compliance initiative
az policy assignment create \
  --name "{initiative-short-name}" \
  --display-name "{initiative display name}" \
  --policy-set-definition "{initiative-id}" \
  --scope "/subscriptions/{subscription-id}"
```

**Option B: ARM Template (for IaC-managed policies)**

```json
{
  "type": "Microsoft.Authorization/policyAssignments",
  "apiVersion": "2024-04-01",
  "name": "{assignment-name}",
  "properties": {
    "displayName": "{display name}",
    "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/{built-in-id}",
    "scope": "/subscriptions/{subscription-id}",
    "enforcementMode": "Default",
    "parameters": {}
  }
}
```

**Enforcement mode guidance:**

| Mode | When to Use |
|------|-------------|
| `Default` | Active enforcement — new non-compliant resources are denied or audited |
| `DoNotEnforce` | Audit-only — evaluates compliance without blocking. Recommended for initial rollout |

### 📋 Policy Gate

The policy gate is **advisory** — it surfaces findings without blocking deployment.

```markdown
### 📋 Policy Gate: ADVISORY

🟡 {N} policies recommended — {M} already covered by template configuration
📊 Compliance coverage: {percentage}% of recommended policies addressed

**Action items:**
- {list of policies to assign}
- {initiative to assign if framework selected}
```

## Output Artifacts

When invoked during a deployment workflow, save results to the deployment directory:

| File | Format | Content |
|------|--------|---------|
| `policy-assessment.md` | Markdown | Full assessment report (Section 4 output) |
| `policy-recommendations.json` | JSON | Structured policy data for automation |

**JSON structure for `policy-recommendations.json`:**
```json
{
  "assessedAt": "2026-04-02T19:00:00Z",
  "deploymentId": "{deployment-id}",
  "framework": "{compliance-framework}",
  "enforcementMode": "Audit",
  "summary": {
    "totalRecommended": 13,
    "alreadyCompliant": 5,
    "gaps": 8
  },
  "policies": [
    {
      "name": "Secure transfer to storage accounts should be enabled",
      "builtInId": "404c3081-a854-4457-ae30-26a93ef643f9",
      "effect": "Deny",
      "severity": "critical",
      "category": "Storage",
      "templateStatus": "compliant",
      "sourceUrl": "https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies#storage"
    }
  ],
  "initiative": {
    "name": "CIS Azure Foundations v3.0.0",
    "builtInId": "{id}",
    "policyCount": 53,
    "coverage": "covers 8 of 13 recommended policies"
  }
}
```

## Integration with AutoCloud

- **Template Generator:** After `/azure-security-analyzer`, optionally invoke `/azure-policy-advisor` to recommend subscription-level policies that complement the template
- **Onboarding:** After RBAC setup, the onboarding flow captures compliance preferences and adds them to `copilot-instructions.md` — this skill reads them automatically
- **Drift Detector:** Cross-reference drift findings with policy recommendations — drift items covered by assigned policies will auto-remediate
