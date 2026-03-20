# AutoCloud - Azure Deployment Agent

> [!WARNING]
> EXPERIMENTAL PROJECT: AutoCloud is in active development and is **not production-ready**.
> Do **not** use this repository to deploy or manage production workloads.
> No SLA, security guarantees, or backward-compatibility guarantees are provided.

## Experimental Status and Usage Limits

- Status: Experimental / preview
- Intended use: Local development, demos, sandbox subscriptions, and learning
- Not supported: Production environments, regulated workloads, or mission-critical systems
- Risk: Workflows, templates, and behavior may change without notice and may cause deployment failures or unexpected changes

If you choose to test this project, use isolated Azure subscriptions/resource groups and non-sensitive data only.

An intelligent GitHub Copilot agent system for deploying Azure resources through a guided, safe, and validated workflow.

## Overview

AutoCloud orchestrates Azure resource deployments through a systematic 4-stage process:

1. **📋 Requirements Gathering** - Interview user to collect deployment details
2. **📝 Template Generation** - Create validated ARM templates with best practices
3. **✅ User Confirmation** - Echo deployment intent and wait for approval
4. **🚀 Deployment Execution** - Deploy resources and run integration tests

## Features

- 🎯 **Guided Workflow** - No more guessing; agent asks targeted questions
- 🔗 **Multi-Resource Deployments** - Deploy application stacks with dependency management
- 🏷️ **CAF-Compliant Naming** - Automatic Cloud Adoption Framework naming with validation
- 💾 **State Persistence** - Deployment artifacts saved to `.azure/deployments/` for audit and reuse
- 🔍 **Drift Detection** - Detect and reconcile manual portal changes or policy remediations
- 🔒 **Safe Deployments** - User confirmation required before any Azure changes
- ⚠️ **Guided Error Recovery** - Pause on failures with diagnostics and recovery options
- 📐 **Best Practices Built-in** - Security, monitoring, and compliance by default
- ✅ **Automated Validation** - Integration tests verify deployed resources
- 📊 **Cost Transparency** - See estimated costs before deployment
- 🔄 **Smart Rollback** - User-guided rollback with partial deployment recovery

## Quick Start

### Prerequisites

1. **VS Code** with GitHub Copilot extension
2. **Azure CLI** installed and authenticated (`az login`)
3. **Azure MCP Server** configured ([setup guide](./docs/AZURE_MCP_SETUP.md))

### Installation

#### Option 1: Install from Copilot CLI Marketplace (recommended)

AutoCloud is published as a [Copilot CLI plugin marketplace](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace). Add the marketplace and install the plugin with:

```bash
# Add the AutoCloud marketplace
copilot plugin marketplace add Azure/autocloud

# Install the autocloud plugin
copilot plugin add autocloud --from Azure/autocloud
```

To update later:

```bash
copilot plugin update autocloud
```

To uninstall:

```bash
copilot plugin remove autocloud
```

#### Option 2: Manual installation

This repository contains agent configuration files that GitHub Copilot automatically discovers.

1. Clone this repository or copy the `.github/` directory to your workspace
2. Open VS Code in the workspace
3. Verify agents are available: Type `@autocloud` for deployments or `@AutoCloud Onboarding` for repo setup

### Configuration

Configure Azure MCP in your VS Code settings:

```json
{
  "azureMcp.serverMode": "namespace",
  "azureMcp.enabledServices": [
    "deploy", "bestpractices", "group", "subscription", 
    "functionapp", "storage", "sql", "monitor"
  ],
  "azureMcp.readOnly": false
}
```

See [Azure MCP Setup Guide](./docs/AZURE_MCP_SETUP.md) for detailed configuration.

### Plugin & Marketplace Structure

AutoCloud is packaged as a **Copilot CLI plugin** with a marketplace listing. The relevant files are:

```
.github/
├── plugin/
│   ├── plugin.json          # Plugin manifest — declares agents/ and skills/ directories
│   ├── marketplace.json     # Marketplace listing — name, version, description, plugins array
│   ├── agents -> ../agents  # Symlink to .github/agents/
│   └── skills -> ../skills  # Symlink to .github/skills/
├── agents/                  # Agent definitions (.agent.md files)
│   ├── autocloud.agent.md
│   ├── autocloudonboarding.agent.md
│   ├── azure-iac-exporter.agent.md
│   ├── azure-principal-architect.agent.md
│   ├── azure-requirements-gatherer.agent.md
│   ├── azure-resource-deployer.agent.md
│   └── azure-template-generator.agent.md
└── skills/                  # Skill definitions (SKILL.md + scripts)
    ├── autocloud-onboarding/
    ├── azure-cost-estimator/
    ├── azure-deployment-preflight/
    ├── azure-drift-detector/
    ├── azure-integration-tester/
    ├── azure-naming-research/
    ├── azure-resource-visualizer/
    ├── azure-role-selector/
    └── azure-security-analyzer/
```

- **`marketplace.json`** ([.github/plugin/marketplace.json](.github/plugin/marketplace.json)) — the marketplace registry file. Copilot CLI recognizes any repository with this file at `.github/plugin/marketplace.json` as a plugin marketplace. The `source` field in each plugin entry points to the directory containing the plugin manifest, relative to the repo root.
- **`plugin.json`** ([.github/plugin/plugin.json](.github/plugin/plugin.json)) — the plugin manifest. Declares the `agents/` and `skills/` directories as relative paths within the plugin directory. Copilot CLI blocks paths that escape the plugin directory (no `../` prefixes), so symlinks inside `.github/plugin/` point to the actual directories at `.github/agents/` and `.github/skills/`.

For more details, see [Creating a plugin marketplace for GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace) and [Finding and installing plugins](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing).

## Usage

### Example 1: Deploy a Python Function App

```
User: @autocloud deploy a Python function app

Agent: I'll help you deploy an Azure Function App through our guided workflow.

Stage 1: Gathering Requirements
-------------------------------
Let me ask a few questions:

1. What region would you like to deploy to? (Default: East US)
2. What should we name the function app? (Suggested: func-<project>-dev-eastus)
3. Which Python version? (3.11, 3.10, 3.9)
4. Hosting plan? (Consumption, Premium, Dedicated)
5. Should I create a new Storage Account or use existing?
6. Enable Application Insights for monitoring?

[User answers questions...]

Requirements collected:
- Resource: Azure Function App (Python 3.11)
- Region: East US
- Plan: Consumption
- Name: func-api-dev-eastus
- Storage: Create new (stfuncapidev8k3m)
- App Insights: Yes

Proceeding to template generation...

Stage 2: Template Generation
-----------------------------
Generated ARM template with:
- Function App (func-api-dev-eastus)
- Storage Account (stfuncapidev8k3m)  
- Application Insights (appi-api-dev-eastus)

Architecture:

┌─────────────────────────────────────────┐
│         rg-api-dev-eastus               │
│                                         │
│  🌐 Internet                            │
│      │                                  │
│      ▼                                  │
│  ⚡ func-api-dev-eastus                 │
│      │              │                   │
│      ▼              ▼                   │
│  💾 stfuncapidev8k3m  📊 appi-api-dev  │
│                                         │
└─────────────────────────────────────────┘

Security features:
✓ HTTPS-only enforcement
✓ Managed identity enabled
✓ TLS 1.2 minimum version
✓ Diagnostic logging configured

Estimated monthly cost: ~$0.40/month (based on 1M executions)

PREVIEW - What will be deployed:
- Resource Group: rg-api-dev-eastus (new)
- Function App: func-api-dev-eastus (Consumption, Python 3.11)
- Storage Account: stfuncapidev8k3m (Standard LRS)
- App Insights: appi-api-dev-eastus

⚠️ USER CONFIRMATION REQUIRED
Type "yes" or "proceed" to deploy these resources.

User: yes

Stage 3: Deployment Execution
------------------------------
🚀 Deployment Started
Operation ID: autocloud-1708272600

⏳ Provisioning Resources...
- ✓ Resource Group: Created (10s)
- ✓ Storage Account: Created (45s)
- ✓ App Insights: Created (15s)
- ✓ Function App: Created (60s)

✅ Deployment Successful (Duration: 2m 10s)

Endpoints:
- Function App: https://func-api-dev-eastus.azurewebsites.net

Stage 4: Integration Testing
-----------------------------
Running integration tests...

✅ Function App endpoint accessible (200 OK)
✅ Response time: 345ms
✅ HTTPS enforcement verified
✅ Application Insights connected
✅ Storage Account accessible

Overall Status: HEALTHY ✅

Next Steps:
1. Deploy your function code: https://docs.microsoft.com/azure/azure-functions/functions-deployment-technologies
2. Configure app settings for your application
3. Monitor in Azure Portal: https://portal.azure.com/#@...

Deployment complete! 🎉
```

### Example 2: Deploy Web App with Database

```
User: @autocloud deploy a web app with SQL database

Agent: I'll deploy a connected web app and SQL database.

Stage 1: Gathering Requirements for both resources...

[Agent asks questions about both resources]

Requirements:
- App Service (web app): app-webapp-dev-eastus
- App Service Plan: plan-webapp-dev-eastus (B1 Basic)
- SQL Server: sql-webapp-dev-eastus
- SQL Database: mydb (Basic tier)
- Connection: Configured via app settings

Stage 2: Template Generation
ARM template includes:
- App Service Plan
- Web App
- SQL Server
- SQL Database
- Connection strings (using managed identity)

Architecture:

┌───────────────────────────────────────────────────┐
│              rg-webapp-dev-eastus                  │
│                                                   │
│  🌐 Internet                                      │
│      │                                            │
│      ▼                                            │
│  🌐 app-webapp-dev-eastus                         │
│      │                    │                       │
│      │ connection string  │ instrumentation key   │
│      ▼                    ▼                       │
│  🗄️ sql-webapp-dev-eastus  📊 appi-webapp-dev     │
│      │                                            │
│      ▼                                            │
│  🗄️ sqldb-webapp-dev                              │
│                                                   │
└───────────────────────────────────────────────────┘

Estimated cost: ~$18/month ($13 App Service + $5 SQL Basic)

Confirm to proceed?

User: proceed

[Deployment executes...]

✅ All resources deployed successfully
✅ Integration tests passed
   - Web app accessible
   - Database connection verified

Your web app is ready at: https://app-webapp-dev-eastus.azurewebsites.net
```

### Example 3: Using the Integration Tester Skill

```
User: /azure-integration-tester

Agent: Please provide deployment outputs or resource details.

User: Test func-api-dev-eastus in rg-api-dev-eastus

Agent: Running integration tests for Function App...

Test Results:
✅ HTTPS endpoint accessible (200 OK)
✅ Response time: 245ms (threshold: 3000ms)
✅ HTTPS enforcement verified
✅ Application Insights connected
⚠️ No custom health endpoint found (using default)

Security Configuration:
✅ HTTPS-only enforced
✅ Managed identity configured
✅ Diagnostic logging enabled

Overall Status: HEALTHY ✅

Recommendations:
1. Add custom health endpoint for better monitoring
2. Configure Application Insights alerts
```

## Deployment State Management

All deployments are persisted to `.azure/deployments/{deployment-id}/` with complete audit trail:

### Directory Structure

```
.azure/deployments/
└── deploy-20260218-143022/
    ├── metadata.json        # Deployment ID, timestamp, user, status
    ├── requirements.json    # Collected deployment parameters
    ├── template.json        # Generated ARM template
    ├── parameters.json      # Template parameters
    ├── architecture.md      # Mermaid architecture diagram
    ├── deployment.log       # Deployment progress and results
    ├── tests.json          # Integration test results
    └── error.log           # Error details (if failed)
```

### Managing Deployment State

Use the built-in deployment manager utility:

```bash
# List all deployments with status
.github/scripts/deployment-manager.sh list

# Show detailed information about a deployment
.github/scripts/deployment-manager.sh show deploy-20260218-143022

# Export deployment as reusable template
.github/scripts/deployment-manager.sh export deploy-20260218-143022 my-template.json

# Clean up old deployments (keep 5 most recent)
.github/scripts/deployment-manager.sh clean 5

# Validate deployment state files
.github/scripts/deployment-manager.sh validate deploy-20260218-143022
```

### Reusing Previous Deployments

```
User: @autocloud deploy the same Function App as last time

Agent: Found previous deployment: deploy-20260218-143022
- Resource: Python Function App (3.11, Consumption)
- Region: East US
- Resource Group: rg-api-dev-eastus

Would you like to:
A. Use the same configuration (update timestamp/name)
B. Modify the configuration before deployment
C. Use a different deployment

User: A

[Agent loads requirements.json, updates names, proceeds...]
```

### Multi-Resource Deployments

Deploy complete application stacks with dependency management:

```
User: @autocloud deploy a web application with database and storage

Agent: I'll help you deploy an application stack.

Detected pattern: Web App Stack
Recommended resources:
- App Service (Web App)
- SQL Database
- Storage Account
- Application Insights

Would you like this configuration or customize?

User: Yes, proceed

[Agent collects requirements for all resources...]

Dependencies detected:
Storage → Web App (connection string)
SQL Database → Web App (connection string)
App Insights → Web App (instrumentation key)

ARM template will deploy resources in this order:
1. Resource Group (if needed)
2. Storage Account
3. SQL Server + Database
4. Application Insights
5. App Service Plan
6. Web App (with all connections configured)

Estimated total cost: $23/month

Confirm to proceed?
```

**Common Application Stacks:**

| Stack Pattern | Resources Included | Use Case |
|--------------|-------------------|----------|
| Serverless API | Function App + Storage + App Insights + Key Vault | REST APIs, webhooks |
| Web Application | App Service + SQL Database + Storage + App Insights | Full-stack web apps |
| Static Frontend | Static Web App + CDN + Storage | React/Vue/Angular SPAs |
| Microservices | Container Apps + Cosmos DB + API Management | Scalable  services |

## Architecture

### Agent System Overview

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                              @autocloud                                       │
│                        Main Orchestrator Agent                                │
│                                                                               │
│  Coordinates all deployment stages, enforces security gates & checkpoints,    │
│  delegates to subagents, invokes skills, and manages deployment state.        │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     ▼
  ┌── Deployment ──┐   ┌── Advisory ──┐    ┌── Import ──────┐
  │   Pipeline      │   │   Agents     │    │   Agent        │
  │                 │   │              │    │                │
  │  ┌───────────┐  │   │ ┌──────────┐ │    │ ┌────────────┐ │
  │  │Requiremnts│  │   │ │Principal │ │    │ │  IaC       │ │
  │  │ Gatherer  │  │   │ │Architect │ │    │ │ Exporter   │ │
  │  └─────┬─────┘  │   │ │ (WAF 5P) │ │    │ │(Reverse-   │ │
  │        │        │   │ └──────────┘ │    │ │ engineer)  │ │
  │        ▼        │   └──────────────┘    │ └────────────┘ │
  │  ┌───────────┐  │                       └────────────────┘
  │  │ Template  │  │
  │  │ Generator │  │
  │  └─────┬─────┘  │
  │        │        │
  │    🔒 Security  │
  │       Gate      │
  │    (BLOCKING)   │
  │        │        │
  │        ▼        │
  │  ┌───────────┐  │
  │  │ Resource  │  │
  │  │ Deployer  │  │
  │  └───────────┘  │
  └─────────────────┘
```

### Subagents (6)

| Subagent | Role | Stage |
|----------|------|-------|
| **Requirements Gatherer** | Interview user, collect params, validate naming (CAF) | Stage 1 |
| **Template Generator** | Generate ARM template, architecture diagram, security analysis | Stage 2 |
| **Resource Deployer** | Execute `az deployment sub create`, monitor, handle failures | Stage 3 |
| **Principal Architect** | WAF 5-pillar review (Security, Reliability, Perf, Cost, Ops) | On-demand |
| **IaC Exporter** | Reverse-engineer live Azure resources into ARM templates | On-demand |
| **AutoCloud Onboarding** | Bootstrap repo/subscription/user access via the `/autocloud-onboarding` skill playbook | On-demand |

### Skills (9)

| Skill | Purpose | Invoked During |
|-------|---------|----------------|
| `/azure-naming-research` | CAF abbreviation lookup, naming constraint validation | Stage 1 (Gatherer) |
| `/azure-security-analyzer` | Per-resource security assessment, gate status | Stage 2 (Generator) |
| `/azure-deployment-preflight` | What-if analysis, permission checks, preflight report | Stage 2 (Generator) |
| `/azure-role-selector` | Least-privilege RBAC role recommendations | Stage 2 / On-demand |
| `/azure-cost-estimator` | Real-time cost estimation via Azure Retail Prices API | Stage 2 (Generator) |
| `/azure-drift-detector` | Detect config drift between live Azure and stored state | Pre-deployment |
| `/azure-integration-tester` | Post-deployment health checks, endpoint tests | Stage 4 |
| `/azure-resource-visualizer` | Generate Mermaid diagrams from live Azure resources | Stage 4 |
| `/autocloud-onboarding` | Guided onboarding for OIDC, RBAC, environments, and secrets using direct `az` and `gh` commands | Setup / On-demand |

### Deployment Pipeline (Stages)

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                     DEPLOYMENT PIPELINE                             │
  │                                                                     │
  │  ┌─────── Optional ───────┐                                        │
  │  │  Pre-Deployment Drift   │                                        │
  │  │  Check (existing only)  │◄── /azure-drift-detector               │
  │  └────────────┬────────────┘                                        │
  │               │                                                     │
  │               ▼                                                     │
  │  ┌─── Stage 1 ────────────┐                                        │
  │  │  Requirements Gathering │◄── /azure-naming-research              │
  │  │  (Subagent)             │                                        │
  │  └────────────┬────────────┘                                        │
  │               │ ✓ User confirms requirements                        │
  │               ▼                                                     │
  │  ┌─── Stage 2 ────────────┐                                        │
  │  │  Template Generation    │◄── /azure-security-analyzer            │
  │  │  & Security Analysis    │◄── /azure-deployment-preflight         │
  │  │  (Subagent)             │◄── /azure-cost-estimator               │
  │  │                         │◄── /azure-role-selector (if RBAC)      │
  │  └────────────┬────────────┘                                        │
  │               │                                                     │
  │               ▼                                                     │
  │  ┌─── Stage 2.5 ──────────┐                                        │
  │  │  🔒 SECURITY GATE       │                                        │
  │  │                         │                                        │
  │  │  All Critical + High    │──── 🟢 PASSED ──┐                      │
  │  │  checks must pass       │                  │                      │
  │  │                         │                  │                      │
  │  │  🔴 BLOCKED:            │                  │                      │
  │  │  A. Auto-fix + re-run ──┤► (loops back     │                      │
  │  │  B. Review individually │   to Stage 2)    │                      │
  │  │  C. Override (explicit) │── ⚠️ ──┐         │                      │
  │  │  D. Abort               │        │         │                      │
  │  └─────────────────────────┘        │         │                      │
  │                                     ▼         ▼                      │
  │  ┌─── Stage 2.75 ─────────┐                                        │
  │  │  Deployment Confirmation │                                        │
  │  │  (Architecture + Plan)   │                                        │
  │  └────────────┬────────────┘                                        │
  │               │ ✓ User approves deployment                          │
  │               ▼                                                     │
  │  ┌─── Stage 3 ────────────┐                                        │
  │  │  Deployment Execution   │                                        │
  │  │  (Subagent)             │── az deployment sub create             │
  │  │  Poll every 30s         │── Monitor nested deployments           │
  │  └────────────┬────────────┘                                        │
  │               │                                                     │
  │               ▼                                                     │
  │  ┌─── Stage 4 ────────────┐                                        │
  │  │  Post-Deploy Validation │◄── /azure-integration-tester           │
  │  │  + Cleanup Instructions │◄── /azure-resource-visualizer          │
  │  └────────────┬────────────┘                                        │
  │               │                                                     │
  │               ▼                                                     │
  │  ┌─────────────────────────┐                                        │
  │  │  📋 Summary + Teardown   │                                        │
  │  │  @autocloud destroy      │                                        │
  │  │  deployment {id}         │                                        │
  │  └─────────────────────────┘                                        │
  └─────────────────────────────────────────────────────────────────────┘
```

### Execution Modes

```
  ┌─────────────────────────────┐     ┌──────────────────────────────────┐
  │     Interactive Mode         │     │     Headless Mode                │
  │     (VS Code / Chat)         │     │     (Coding Agent / Actions)     │
  │                              │     │                                  │
  │  User ◄──► AutoCloud Agent   │     │  Issue ──► Agent (on branch)     │
  │  • Real-time Q&A             │     │  • Parse requirements from body  │
  │  • az login session          │     │  • OIDC auth via Actions         │
  │  • Interactive confirmation  │     │  • Commit artifacts to PR        │
  │  • Direct deployment         │     │  • Workflows handle deploy       │
  │                              │     │                                  │
  │  Destroy:                    │     │  Deployed via:                   │
  │  @autocloud destroy {id}     │     │  • autocloud-plan.yml (PR)       │
  │                              │     │  • autocloud-deploy.yml (merge)  │
  │                              │     │  • autocloud-destroy.yml (/cmd)  │
  └─────────────────────────────┘     └──────────────────────────────────┘
```

### State & Artifacts

Each deployment creates a directory under `.azure/deployments/{deployment-id}/`:

```
.azure/deployments/deploy-20260219-105020/
├── requirements.json          # Collected parameters
├── template.json              # ARM template
├── parameters.json            # Template parameters
├── architecture.md            # Mermaid diagram
├── security-analysis.md       # Per-resource security report
├── cost-estimate.json         # Per-resource cost breakdown (from API)
├── security-gate.json         # Gate result (PASSED/BLOCKED/OVERRIDDEN)
├── deployment.log             # Deployment progress & results
├── tests.json                 # Integration test results
├── state.json                 # Final state (Succeeded/Destroyed)
└── metadata.json              # Deployment ID, timestamp, user
```

## CAF-Compliant Naming

AutoCloud uses the **azure-naming-research** skill to ensure all resource names follow the [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations) naming conventions.

### How It Works

**During Requirements Gathering:**
```
User: @autocloud deploy a Function App

Agent: I'll help you deploy an Azure Function App.

What would you like to name the Function App?

CAF recommendation: func-{project}-{environment}-{region}
Example: func-api-dev-eastus

Azure constraints (validated via azure-naming-research):
- Length: 2-60 characters
- Format: alphanumeric + hyphens
- Scope: globally unique
- Must start/end with alphanumeric character

Suggested: func-api-dev-eastus
Your choice:
```

**If User Provides Custom Name:**
```
User: myapp123

Agent: ⚠️ Name validation failed

The name "myapp123" doesn't follow CAF conventions.
CAF abbreviation for Function App: func

Also, checking Azure constraints:
✓ Length: valid (8 chars, needs 2-60)
✓ Characters: valid (alphanumeric only)
✗ CAF format: should be func-{project}-{env}-{region}

Would you like me to:
A. Auto-fix to CAF format: func-myapp123-dev-eastus
B. Suggest a valid alternative
C. Let me try a different name
```

### Supported Resource Name Patterns

| Resource Type | CAF Abbreviation | Example |
|--------------|------------------|---------|
| Resource Group | `rg` | rg-webapp-prod-eastus |
| Function App | `func` | func-api-dev-westus2 |
| App Service | `app` | app-webapp-staging-eastus |
| App Service Plan | `asp` | asp-webapp-prod-eastus |
| Storage Account | `st` | stwebappdev8k3m |
| SQL Server | `sql` | sql-webapp-prod-eastus |
| SQL Database | `sqldb` | sqldb-webapp-prod |
| Cosmos DB | `cosmos` | cosmos-api-prod-eastus |
| Application Insights | `appi` | appi-webapp-prod-eastus |
| Key Vault | `kv` | kv-webapp-prod-eus |
| Container App | `ca` | ca-api-prod-eastus |

### Name Validation

The agent validates ALL names against:
1. **CAF abbreviation** - Correct resource type prefix
2. **Length constraints** - Azure min/max character limits
3. **Character rules** - Allowed characters (alphanumeric, hyphens, etc.)
4. **Uniqueness scope** - Global vs resource group vs subscription
5. **Start/end rules** - Must begin/end with valid characters

**Multi-Resource Consistency:**
```
User: @autocloud deploy a web app with database and storage

Agent: I'll deploy a Web App Stack (3 resources)

To ensure consistent naming, what's your project name?
User: webapp

Agent: Perfect! I'll use these CAF-compliant names:
- Resource Group:      rg-webapp-dev-eastus
- App Service Plan:    asp-webapp-dev-eastus
- App Service:         app-webapp-dev-eastus
- Storage Account:     stwebappdev8k3m
- SQL Server:          sql-webapp-dev-eastus
- SQL Database:        sqldb-webapp-dev
- Application Insights: appi-webapp-dev-eastus

All names validated ✓
Proceed with deployment?
```

## Configuration Drift Detection

AutoCloud can detect when Azure resources have been modified outside the IaC workflow (manual portal changes, Azure Policy remediations) and help you reconcile the differences.

### Common Drift Scenarios

**Scenario 1: Azure Policy Remediation**
```
User: @autocloud check for drift on deploy-20260218-143022

Agent: Analyzing configuration drift...

⚠️ Configuration Drift Detected

Deployment: deploy-20260218-143022 (Function App)
Critical Drift: 1
Warning Drift: 1

Changes detected:
🔴 httpsOnly: false → true (Critical - Security)
   Azure Policy "Require HTTPS" enforced this change
   
🟡 tags.CostCenter: "" → "12345" (Warning - Tags)
   Tag was added manually via Azure Portal

Options:
A. **Accept Drift** - Update your IaC (requirements.json) to match Azure
B. **Revert Drift** - Redeploy to restore original configuration
C. **Review Details** - See full drift report
D. **Ignore** - Mark as known drift (won't alert again)

Type A, B, C, or D:

User: A

Agent: Accepting drift and updating IaC...

✓ Backed up original state
✓ Updated requirements.json with current Azure values
✓ Logged drift acceptance to audit trail

Your IaC now matches Azure. Next deployment will preserve:
- httpsOnly: true (security improvement)
- tags.CostCenter: "12345" (compliance tag)
```

**Scenario 2: Emergency Hotfix**
```
User: Someone changed the function app runtime in production via the portal. What happened?

Agent: I'll check for drift in your production deployments...

Found deployment: deploy-20260215-093022 (func-api-prod-eastus)

⚠️ Configuration Drift Detected

Changes:
🟡 FUNCTIONS_WORKER_RUNTIME: python → dotnet (Warning - Runtime)
🟡 FUNCTIONS_EXTENSION_VERSION: ~4 → ~3 (Warning - Version)

Last modified: 2026-02-18 14:30 UTC
Modified by: john.doe@company.com

This looks like an emergency change. What would you like to do?

A. **Accept Drift** - Keep the .NET runtime (update your IaC)
B. **Revert Drift** - Restore Python runtime from IaC
C. **Investigate** - View Azure Portal activity logs

User: C

Agent: Opening activity logs...

Recent changes to func-api-prod-eastus:
- 14:30 UTC: App Settings modified by john.doe@company.com
- Reason: "Emergency rollback due to Python dependency issue"

Would you like to accept this drift or revert?
```

**Scenario 3: Unauthorized Change**
```
User: /azure-drift-detector --deployment-id deploy-20260218-143022

Agent: Running drift detection...

⚠️ Configuration Drift Detected

Changes:
🔴 minimumTlsVersion: "1.2" → "1.0" (Critical - Security)
   ⚠️ This weakens security posture!

🟡 httpsOnly: true → false (Critical - Security)
   ⚠️ Allows unencrypted traffic!

Last modified: 2026-02-18 16:45 UTC
Modified by: unknown

🚨 RECOMMENDATION: Revert immediately (Option B)

These changes introduce security vulnerabilities and likely violate your compliance policy.

Type B to revert:

User: B

Agent: Reverting security changes...

🚀 Deployment Started (revert)
⏳ Restoring secure configuration...
- ✓ minimumTlsVersion: 1.0 → 1.2 (restored)
- ✓ httpsOnly: false → true (restored)

✅ Drift reverted successfully

Security posture restored. Consider:
1. Reviewing Azure RBAC permissions
2. Enabling resource locks for production
3. Setting up drift monitoring alerts
```

### Drift Detection Workflow

**1. Scheduled Drift Monitoring**
```bash
# Check all deployments for drift
.github/skills/azure-drift-detector/scripts/drift-check-all.sh

# Output
Scanning 12 deployments for drift...

🔴 deploy-20260215-093022 - Critical: 2, Warning: 0
🟡 deploy-20260216-143022 - Warning: 3
✓ deploy-20260217-100000 - No drift
✓ deploy-20260218-143022 - No drift

═══════════════════════════════════════════
Drift Scan Results
═══════════════════════════════════════════

Deployments checked: 12
Deployments with drift: 2
Critical drifts: 2
Warning drifts: 3
```

**2. Single Deployment Check**
```bash
# Check specific deployment
.github/skills/azure-drift-detector/scripts/detect-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --output-format markdown

# Generates drift report
.azure/deployments/deploy-20260218-143022/drift-analysis/
├── drift-details.json     # Machine-readable drift data
├── drift-report.md        # Human-readable report
└── current-*.json         # Current Azure state snapshots
```

**3. Accept Drift (Update IaC)**
```bash
# Accept Azure changes and update requirements.json
.github/skills/azure-drift-detector/scripts/accept-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --reason "Azure Policy compliance" \
  --auto-commit

# Results
✓ Backed up original state
✓ Updated requirements.json with Azure values
✓ Logged to drift-log.jsonl
✓ Git commit created
```

**4. Revert Drift (Restore IaC)**
```bash
# Redeploy to restore desired state
.github/skills/azure-drift-detector/scripts/revert-drift.sh \
  --deployment-id deploy-20260218-143022 \
  --confirm

# Results
🚀 Deployment Started (revert)
✓ httpsOnly: false → true (restored)
✓ minimumTlsVersion: 1.0 → 1.2 (restored)
✅ Drift reverted successfully
```

### Automated Drift Monitoring

Add drift detection to your CI/CD pipeline:

**GitHub Actions Example:**
```yaml
name: Azure Drift Detection

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  drift-detection:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Check All Deployments for Drift
        run: |
          .github/skills/azure-drift-detector/scripts/drift-check-all.sh \
            --format json > drift-report.json
      
      - name: Report Critical Drift
        if: ${{ failure() }}
        run: |
          # Extract critical drifts
          jq -r '.deployments[] | select(.criticalDrift > 0) | 
            "🔴 \(.deploymentId): \(.criticalDrift) critical drifts"' \
            drift-report.json
          
          # Post to Slack/Teams/PagerDuty
          # ... your notification logic
      
      - name: Upload Drift Report
        uses: actions/upload-artifact@v3
        with:
          name: drift-report
          path: drift-report.json
```

### Drift Categories

| Severity | Example | Impact | Recommendation |
|----------|---------|--------|----------------|
| 🔴 **Critical** | `httpsOnly: false`, `minimumTlsVersion: 1.0` | Security vulnerability | Revert immediately |
| 🟡 **Warning** | Tag changes, non-security config | Compliance/consistency | Accept or revert based on change |
| ℹ️ **Info** | Cosmetic changes, Azure-managed props | Low/none | Usually safe to accept |

### Audit Trail

All drift actions are logged to `.azure/deployments/{id}/drift-analysis/drift-log.jsonl`:

```jsonl
{"timestamp":"2026-02-18T14:30:00Z","action":"accept","user":"john.doe","driftsAccepted":2,"reason":"Azure Policy compliance"}
{"timestamp":"2026-02-18T16:45:00Z","action":"revert","user":"jane.smith","revertDeploymentId":"deploy-20260218-164500-revert","driftsReverted":3}
```

## Supported Azure Resources

| Resource Type | Status | Features |
|---------------|--------|----------|
| Resource Groups | ✅ Supported | Create, tag, delete |
| Function Apps | ✅ Supported | Python, Node.js, .NET, Java |
| App Services | ✅ Supported | Web Apps, APIs |
| Storage Accounts | ✅ Supported | Blob, Table, Queue, File |
| SQL Database | ✅ Supported | Single, Elastic Pool |
| Cosmos DB | ✅ Supported | SQL API, MongoDB |
| Application Insights | ✅ Supported | Auto-configured with apps |
| Key Vault | ✅ Supported | Secrets, keys, certificates |
| Container Apps | ✅ Supported | Managed containers with ingress |
| Container Apps Environments | ✅ Supported | Shared hosting for Container Apps |
| Log Analytics Workspaces | ✅ Supported | Required by Container Apps, monitoring |
| AKS | 🚧 Planned | Complex networking setup |
| Virtual Machines | ❌ Not planned | Use other tools |

## Configuration

### Workspace Instructions

Customize deployment standards in [.github/copilot-instructions.md](.github/copilot-instructions.md):

- Naming conventions (CAF-compliant)
- Default regions (East US, West US 2, West Europe)
- Environment tags
- Security baselines
- ARM template standards
- Multi-environment configuration

### Onboarding

Set up OIDC, RBAC, and GitHub environments with the `@AutoCloud Onboarding` agent or the `/autocloud-onboarding` skill.

The onboarding workflow is skill-driven and executes Azure CLI / GitHub CLI commands directly. See the [Onboarding Guide](./docs/ONBOARDING.md).

### Integration Tests

Customize test scripts in [.github/skills/azure-integration-tester/scripts/](.github/skills/azure-integration-tester/scripts/):

- `test-function-app.sh` - Function App health checks
- `test-storage.sh` - Storage Account operations
- `test-database.sh` - Database connectivity

## Troubleshooting

### Common Issues

**Agent not appearing in picker**
- Reload VS Code window: `Cmd/Ctrl + Shift + P` → "Reload Window"
- Verify `.github/agents/` directory exists in workspace

**Azure MCP tools not available**
- Check Azure MCP configuration in settings
- Verify Azure CLI is authenticated: `az account show`
- See [Azure MCP Setup Guide](./docs/AZURE_MCP_SETUP.md)

**Deployment fails with permission error**
- Verify Azure account has Contributor role
- Check: `az role assignment list --assignee $(az account show --query user.name -o tsv)`
- Run the verification workflow: `gh workflow run autocloud-verify.yml`

**OIDC login fails in GitHub Actions**
- Verify federated credentials match your environment names exactly
- Check the `subject` field and whether the GitHub org uses default or ID-based OIDC subjects
- Re-run onboarding through `@AutoCloud Onboarding` or `/autocloud-onboarding`
- See [Onboarding Troubleshooting](./docs/ONBOARDING.md#troubleshooting)

**Integration tests fail**
- Resources may still be starting (wait 2-3 minutes)
- Check firewall rules allow your IP
- Review logs: `az webapp log tail --name <app-name> --resource-group <rg>`

**Deployment fails mid-process**
- Agent will pause and present recovery options:
  - **Retry** - Attempt deployment again (for transient errors)
  - **Modify** - Go back to fix configuration
  - **Rollback** - Remove partially created resources
  - **Investigate** - View detailed logs in Azure Portal
  - **Abort** - Keep partial resources and exit
- Check `.azure/deployments/{deployment-id}/error.log` for details
- Partial deployments are tracked; agent shows which resources succeeded/failed

**Rollback needed after deployment**
```bash
# View deployment details
.github/scripts/deployment-manager.sh show deploy-20260218-143022

# Manually delete resources (agent will guide you)
az resource delete --ids {resource-id}

# Or delete entire resource group if it was created new
az group delete --name {rg-name} --yes

# Or use the destroy command on a PR/issue
# /destroy deploy-20260218-143022
```

**Multi-environment secrets not resolving**
- Ensure environment-level secrets are set, not just repo-level secrets
- Verify the `environment` field in your workflow job matches the GitHub environment name
- Check: `gh secret list --repo your-org/your-repo --env azure-deploy-prod`

## Security

### Best Practices

- ✅ User confirmation required before deployments
- ✅ HTTPS-only enforcement on all resources
- ✅ Managed identities instead of connection strings
- ✅ TLS 1.2 minimum on all services
- ✅ Diagnostic logging enabled by default
- ✅ Cost estimates shown before deployment

### Credential Management

- Never commit Azure credentials to version control
- Use `.env` for local development (add to `.gitignore`)
- In production, use managed identities

### Least Privilege

Agents require minimum Azure permissions:
- **Requirements Gatherer**: Reader role
- **Template Generator**: Reader role
- **Resource Deployer**: Contributor role

## Contributing

Contributions welcome! Areas for improvement:

- [ ] AKS deployment support
- [ ] Bicep template generation (in addition to ARM)
- [ ] Cost estimation improvements
- [ ] More integration test coverage
- [ ] Multi-region deployment support
- [ ] Promotion workflows (dev → staging → prod)

## License

MIT License - see [LICENSE](LICENSE) for details

## Resources

- [Onboarding Guide](./docs/ONBOARDING.md) - Set up OIDC, RBAC, environments
- [Deployment State](./docs/DEPLOYMENT_STATE.md) - State management and artifact tracking
- [Drift Detection](./docs/DRIFT_DETECTION.md) - Configuration drift monitoring
- [Azure MCP Setup](./docs/AZURE_MCP_SETUP.md) - VS Code Azure MCP configuration
- [GitHub Copilot Custom Agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
- [Azure ARM Templates](https://docs.microsoft.com/azure/azure-resource-manager/templates/)
- [Azure MCP Server](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azure-mcp-server)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)

## Acknowledgments

Built with:
- GitHub Copilot Agent Framework
- Azure MCP Server
- Azure CLI
- Azure Resource Manager

---

**Need help?** Open an issue or consult the [Azure MCP Setup Guide](./docs/AZURE_MCP_SETUP.md)
