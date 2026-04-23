# Companion plugin: `@microsoft/azure-skills`

Git-Ape integrates with the [microsoft/azure-skills](https://github.com/microsoft/azure-skills) plugin as a **recommended companion install**. Some Git-Ape agents and skills delegate to skills provided by `@microsoft/azure-skills` (e.g., `/azure-rbac`, `/azure-prepare`, `/azure-validate`, `/azure-diagnostics`). Installing it alongside Git-Ape is required for full functionality, but Git-Ape remains functional without it — agents will prompt you to install it at the point of need.

See [docs/investigations/azure-skills-plugin.md](investigations/azure-skills-plugin.md) for the full overlap analysis and decision rationale.

## What the companion provides

| Capability | Upstream skill | How Git-Ape uses it |
|---|---|---|
| Least-privilege RBAC | `/azure-rbac` | Replaces deprecated local `/azure-role-selector` |
| Azure readiness prep | `/azure-prepare` | Called from `/prereq-check` for Azure-specific readiness |
| Template/config validation | `/azure-validate` | Secondary validator alongside Checkov / ARM-TTK / PSRule / Template Analyzer |
| Post-deploy diagnostics | `/azure-diagnostics` | Invoked on `git-ape-verify.yml` failures |
| Cost optimization | `/azure-cost` | Ad-hoc optimization queries (local `/azure-cost-estimator` handles pre-deploy cost estimation) |
| Workload skills | `/azure-compute`, `/azure-kubernetes`, `/azure-storage`, `/azure-messaging`, `/azure-ai`, `/azure-aigateway`, `/microsoft-foundry`, etc. | Opt-in per deployment, invoked by the requirements gatherer and template generator |

## Install

### GitHub Copilot CLI

```bash
/plugin marketplace add microsoft/azure-skills
/plugin install azure@azure-skills
```

### VS Code

Install the [Azure MCP Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azure-mcp-server). It installs a companion extension that brings the Azure skills layer into VS Code automatically.

### Claude Code

```bash
/plugin marketplace add microsoft/azure-skills
/plugin install azure@azure-skills
```

### Gemini CLI

```bash
gemini extensions install https://github.com/microsoft/azure-skills
```

## Verify

After install, confirm the skills are discoverable:

```text
/azure-rbac
/azure-prepare
/azure-validate
```

Each should respond with its skill documentation.

## Name collision

Both Git-Ape and `@microsoft/azure-skills` previously shipped a skill named `azure-resource-visualizer`. Git-Ape has **renamed its local skill to `/git-ape-resource-visualizer`** so both can coexist:

| Use case | Invoke |
|---|---|
| Visualize a Git-Ape deployment (uses `.azure/deployments/<id>/state.json`) | `/git-ape-resource-visualizer` |
| Visualize any other Azure resource group | `/azure-resource-visualizer` (upstream) |

## Authentication

Both plugins use the same Azure auth paths:

- **Interactive (local):** `az login` (and `azd auth login` for `azd`-backed workflows)
- **Headless (GitHub Actions):** OIDC via [`azure/login@v2`](https://github.com/Azure/login) — see [docs/ONBOARDING.md](ONBOARDING.md)
- **Managed identity** when running inside Azure

Git-Ape's headless workflows (`git-ape-plan`, `git-ape-deploy`, `git-ape-verify`, `git-ape-destroy`) authenticate via OIDC before any upstream skill runs, so delegated skills inherit the same credentials.

## Prerequisites

The companion plugin requires Node.js 18+ (for `npx`) because it starts the Azure MCP Server and Foundry MCP via `npx` at runtime. `/prereq-check` verifies Node 18+ and optionally checks that the companion plugin is installed.

## Telemetry

To disable the companion plugin's MCP telemetry:

```bash
export AZURE_MCP_COLLECT_TELEMETRY=false
```

## Delegation contract

When a Git-Ape agent delegates to an upstream skill:

1. The agent invokes the upstream skill by name (e.g., `/azure-rbac`).
2. The agent wraps the output in Git-Ape's deployment-state contract if the result needs to be persisted (e.g., role assignments captured in `.azure/deployments/<id>/state.json`).
3. If the upstream skill is not available, the agent **stops and prompts the user to install** this companion plugin — it does **not** fabricate a local fallback.

## References

- Upstream repository: <https://github.com/microsoft/azure-skills>
- Upstream skills directory: <https://github.com/microsoft/azure-skills/tree/main/skills>
- Investigation report: [docs/investigations/azure-skills-plugin.md](investigations/azure-skills-plugin.md)
- Tracking issue: [Azure/git-ape#13](https://github.com/Azure/git-ape/issues/13)
