![AutoCloud APE logo](docs/APE.png)

# AutoCloud

> [!WARNING]
> EXPERIMENTAL PROJECT: AutoCloud is in active development and is not production-ready.
> Use it for local development, demos, sandbox subscriptions, and learning only.

AutoCloud is a **platform engineering framework** built on GitHub Copilot. It provides a structured, multi-agent system for planning, validating, and deploying Azure infrastructure — with security gates, cost analysis, drift detection, and CI/CD pipeline integration built in.

## What It Is

AutoCloud packages a set of Copilot agents and skills focused on Azure infrastructure work.

- It helps you gather deployment requirements.
- It generates ARM templates and supporting deployment artifacts.
- It runs security, preflight, and cost checks before deployment.
- It supports onboarding, drift detection, and post-deployment validation.

## What It Does

AutoCloud is designed around a simple deployment flow:

1. Collect the inputs for the resources you want.
2. Generate and review the template, naming, cost, and security results.
3. Ask for confirmation before anything changes in Azure.
4. Deploy and run follow-up validation.

Common tasks it supports:

- Deploying Azure application stacks such as Function Apps, Web Apps, Storage, SQL, Cosmos DB, and Container Apps.
- Bootstrapping repository onboarding for OIDC, RBAC, GitHub environments, and secrets.
- Saving deployment artifacts under `.azure/deployments/` for audit and reuse.
- Detecting configuration drift between Azure and stored deployment state.

## Get Started

### Prerequisite
- Only tested with BASH shells (git-bash for windows)

### 1. Install the plugin

Recommended:

```bash
copilot plugin marketplace add Azure/autocloud
copilot plugin install Azure/autocloud
```

Manual option:

1. Clone this repository.
2. Open it in VS Code with GitHub Copilot enabled.
3. Confirm the agents appear in chat.

### 2. Configure Azure access

1. Install Azure CLI and sign in with `az login`.
2. Configure the Azure MCP server in VS Code.
3. Verify the required Azure services are enabled.

Setup details are in [docs/AZURE_MCP_SETUP.md](docs/AZURE_MCP_SETUP.md).

### 3. Use the agents

Start with one of these prompts in Copilot Chat:

- `@autocloud deploy a Python function app`
- `@autocloud deploy a web app with SQL database`
- `@AutoCloud Onboarding set up this repo for Azure deployments`

### 4. Tear Down
Use @autocloud to clean up afterwards by using:
- `@autocloud destroy Python function app`

## Where To Go Next

- [docs/EXAMPLES.md](docs/EXAMPLES.md): Longer end-to-end examples and sample conversations.
- [docs/ONBOARDING.md](docs/ONBOARDING.md): Repository onboarding, OIDC, RBAC, and GitHub environment setup.
- [docs/AZURE_MCP_SETUP.md](docs/AZURE_MCP_SETUP.md): Azure MCP server configuration for VS Code.
- [docs/DEPLOYMENT_STATE.md](docs/DEPLOYMENT_STATE.md): How deployment artifacts are stored and reused.
- [docs/DRIFT_DETECTION.md](docs/DRIFT_DETECTION.md): Detecting and reconciling Azure drift.

## Architecture

`@autocloud` is the central orchestrator. It coordinates a deployment pipeline of specialized subagents, enforces security gates, invokes skills, and manages deployment state. It does not deploy anything without explicit user confirmation.

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

### Subagents

| Subagent | Role |
|----------|------|
| **Requirements Gatherer** | Interviews user, collects params, validates CAF naming |
| **Template Generator** | Generates ARM template, architecture diagram, security analysis |
| **Resource Deployer** | Executes `az deployment sub create`, monitors progress, handles failures |
| **Principal Architect** | WAF 5-pillar review (Security, Reliability, Perf, Cost, Ops) |
| **IaC Exporter** | Reverse-engineers live Azure resources into ARM templates |
| **AutoCloud Onboarding** | Bootstraps repo/subscription/user access via the onboarding skill |

### Skills

| Skill | Purpose |
|-------|----------|
| `/azure-naming-research` | CAF abbreviation lookup, naming constraint validation |
| `/azure-security-analyzer` | Per-resource security assessment with blocking gate |
| `/azure-deployment-preflight` | What-if analysis and permission checks before deploy |
| `/azure-role-selector` | Least-privilege RBAC role recommendations |
| `/azure-cost-estimator` | Real-time cost estimation via Azure Retail Prices API |
| `/azure-drift-detector` | Detect config drift between live Azure and stored state |
| `/azure-integration-tester` | Post-deployment health checks and endpoint tests |
| `/azure-resource-visualizer` | Generate Mermaid diagrams from live Azure resources |
| `/autocloud-onboarding` | Guided setup for OIDC, RBAC, environments, and secrets |

### Execution Modes

AutoCloud works in two modes — same agents and skills, different execution context.

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
  │                              │     │  • autocloud-destroy.yml (merge) │
  └─────────────────────────────┘     └──────────────────────────────────┘
```

**Interactive** — you talk to `@autocloud` in VS Code Copilot Chat, authenticate via `az login`, and approve each step in real time.

**Headless** — the Copilot Coding Agent picks up a GitHub issue, generates the template on a branch, opens a PR, and the CI/CD workflows (`autocloud-plan`, `autocloud-deploy`, `autocloud-destroy`) handle validation, deployment, and teardown via OIDC.

## Included Components

AutoCloud is packaged as a Copilot CLI plugin with agents and skills under `.github/`:

```
plugin.json                   # Plugin manifest
.github/
├── agents/                   # Subagent definitions (.agent.md)
└── skills/                   # Skill definitions (SKILL.md + scripts)
```

See [plugin.json](plugin.json) and [.github/plugin/marketplace.json](.github/plugin/marketplace.json) for packaging details.

## License

MIT License. See [LICENSE](LICENSE).
