# Investigation: Integrating `@microsoft/azure-skills` into Git-Ape

Tracking issue: [Azure/git-ape#13](https://github.com/Azure/git-ape/issues/13)

Status: Research & report (Scope A). No code, manifest, or workflow changes made in this PR.

## 1. Executive summary

[microsoft/azure-skills](https://github.com/microsoft/azure-skills) is an official Microsoft-published Copilot plugin that ships ~25 curated Azure skills plus wiring for the Azure MCP Server and Foundry MCP. It is packaged for multiple runtimes (GitHub Copilot CLI, VS Code, Claude Code, Cursor, Gemini CLI, IntelliJ).

Git-Ape today is a thinner Copilot plugin focused on an opinionated ARM-template deployment lifecycle (requirements → template → security gate → deploy → verify → destroy) backed by 13 local skills and 8 orchestration agents. It overlaps with upstream in three skills and complements it in most others.

**Recommendation:** adopt a **coexist + delegate** model: keep Git-Ape's orchestration surface (agents, workflows, deployment-state contract) as the primary value-add, and declare `@microsoft/azure-skills` as an **optional companion plugin** that Git-Ape agents can delegate to (via `/skill-name` invocation) where upstream provides broader or better-maintained coverage. Retire one local skill outright (`azure-role-selector` → upstream `azure-rbac`), rename one to resolve a name collision (`azure-resource-visualizer` → `git-ape-resource-visualizer`), and keep the remainder of the local skill surface because it encodes Git-Ape-specific contracts.

## 2. Current state — Git-Ape

Sources: [plugin.json](../../plugin.json), [.github/plugin/marketplace.json](../../.github/plugin/marketplace.json), [.github/skills/](../../.github/skills), [.github/agents/](../../.github/agents).

**Packaging**

- Single `plugin.json` at repo root pointing `agents` → `.github/agents/` and `skills` → `.github/skills/`.
- `.github/plugin/marketplace.json` declares a single plugin entry with `source: "."`.
- No `.claude-plugin`, `.cursor-plugin`, `gemini-extension.json`, or `.mcp.json` manifest — Git-Ape is Copilot-only today.
- Azure MCP is set up out-of-band via [docs/AZURE_MCP_SETUP.md](../AZURE_MCP_SETUP.md), not bundled.

**Local skills (13)**

| Skill | Role in Git-Ape flow |
|-------|----------------------|
| `prereq-check` | Tooling and auth preflight |
| `git-ape-onboarding` | OIDC / federated cred / RBAC bootstrap |
| `azure-naming-research` | CAF abbreviation + naming-rule lookup |
| `azure-resource-availability` | SKU, runtime version, API version, quota live checks |
| `azure-rest-api-reference` | ARM property/schema lookup for template authoring |
| `azure-security-analyzer` | Per-resource security assessment (blocking gate) |
| `azure-policy-advisor` | Azure Policy compliance assessment |
| `azure-role-selector` | Least-privilege RBAC role recommendations |
| `azure-cost-estimator` | Retail-price API cost breakdown |
| `azure-deployment-preflight` | `what-if` + permission checks before deploy |
| `azure-integration-tester` | Post-deploy smoke tests |
| `azure-drift-detector` | State vs. deployed resource diff |
| `azure-resource-visualizer` | Mermaid architecture diagram from deployed RG |

**Agents (8)**: `git-ape`, `git-ape-onboarding`, `azure-requirements-gatherer`, `azure-template-generator`, `azure-resource-deployer`, `azure-principal-architect`, `azure-iac-exporter`, `azure-policy-advisor`.

**Workflows (headless)**: `git-ape-plan`, `git-ape-deploy`, `git-ape-verify`, `git-ape-destroy` (under [.github/workflows/](../../.github/workflows/), currently with `.exampleyml` extension).

## 3. Upstream inventory — `@microsoft/azure-skills`

Source: [microsoft/azure-skills/tree/main/skills](https://github.com/microsoft/azure-skills/tree/main/skills) (synced from `microsoft/GitHub-Copilot-for-Azure`).

**Multi-runtime packaging**

- Root `plugin.json`, `gemini-extension.json`, `.mcp.json`, `.claude-plugin/`, `.cursor-plugin/`.
- Bundles Azure MCP Server + Foundry MCP wiring.
- Installed via `/plugin install azure@azure-skills` (Copilot CLI / Claude Code), `gemini extensions install …`, or the VS Code Azure MCP extension companion.

**Skills directory (observed on main)**

`airunway-aks-setup`, `appinsights-instrumentation`, `azure-ai`, `azure-aigateway`, `azure-cloud-migrate`, `azure-compliance`, `azure-compute`, `azure-cost`, `azure-deploy`, `azure-diagnostics`, `azure-enterprise-infra-planner`, `azure-hosted-copilot-sdk`, `azure-kubernetes`, `azure-kusto`, `azure-messaging`, `azure-prepare`, `azure-quotas`, `azure-rbac`, `azure-resource-lookup`, `azure-resource-visualizer`, `azure-storage`, `azure-upgrade`, `azure-validate`, `entra-app-registration`, `microsoft-foundry`.

Authoritative set (25); upstream README marketing copy says "20 curated" — treat the directory listing as ground truth.

## 4. Overlap / gap / decision matrix

Decisions are proposals for maintainer sign-off. "Delegate" means the local Git-Ape agent invokes the upstream skill rather than Git-Ape shipping its own implementation.

### 4.1 Direct overlap

| Git-Ape skill | Upstream skill | Overlap | Proposed decision | Rationale |
|---|---|---|---|---|
| `azure-cost-estimator` | `azure-cost` | Both estimate/optimize cost | **Coexist (delegate for optimization)** | Local skill targets pre-deploy cost prediction from ARM templates via Retail Prices API — a narrow, Git-Ape-specific contract. Upstream covers broader subscription-wide cost optimization. Keep both; have the `azure-principal-architect` agent delegate ad-hoc optimization questions to `/azure-cost`. |
| `azure-role-selector` | `azure-rbac` | RBAC role recommendation | **Adopt upstream, deprecate local** | Upstream is a superset. Plan deprecation with a shim that forwards `/azure-role-selector` → `/azure-rbac`. |
| `azure-resource-availability` | `azure-quotas` | Quota + SKU availability | **Coexist — split responsibilities** | Local skill does SKU restrictions + K8s/runtime versions + API-version compatibility, not just quota. Retain local; delegate pure quota lookups. |
| `azure-resource-visualizer` | `azure-resource-visualizer` | **Name collision** | **Rename local → `git-ape-resource-visualizer`** | Local skill is tightly coupled to `.azure/deployments/*/state.json` and Mermaid architecture format used by `git-ape-plan.yml`. Rename avoids invocation ambiguity when both plugins are installed. |
| IaC Exporter agent | `azure-resource-lookup` | Resource inventory + export | **Complementary** | Local agent produces Git-Ape-compatible templates; upstream is generic lookup. Agent can call `/azure-resource-lookup` during export. |

### 4.2 Strong candidates — fill gaps

| Upstream skill | Git-Ape slot | Proposed decision |
|---|---|---|
| `azure-prepare` | Pairs with `prereq-check` | **Delegate** from `prereq-check` for Azure-specific readiness |
| `azure-validate` | Stage 2 (template generator) | **Delegate** as a secondary validator alongside Checkov / ARM-TTK / PSRule / Template Analyzer (which remain the primary mandatory gates per [copilot-instructions](../../.github/copilot-instructions.md)) |
| `azure-deploy` | Stage 3 (resource deployer) | **Coexist** — Git-Ape's `azure-resource-deployer` is tied to the Git-Ape deployment-state contract (`.azure/deployments/*/state.json`, `metadata.json`); do not replace. Consider delegating for non-Git-Ape one-off deploys. |
| `azure-diagnostics` | Stage 4 (verify) — new | **Adopt** — invoke from `git-ape-verify.yml` and failed-deployment paths |
| `azure-upgrade` | Day-2 ops — new | **Adopt** |
| `azure-cloud-migrate` | Onboarding — new | **Adopt (opt-in)** |
| `azure-compliance` | Security gate | **Coexist** — keep `azure-security-analyzer` as the blocking gate; add `azure-compliance` as an advisory layer alongside `azure-policy-advisor` |
| `azure-enterprise-infra-planner` | Stage 1 (requirements) — new | **Adopt (opt-in)** for landing-zone scenarios |
| `entra-app-registration` | Onboarding | **Evaluate replacement of the Entra portion of `git-ape-onboarding`** — upstream may be a better fit for the app-registration + federated-credential steps; local onboarding retains GitHub environment + secrets setup that upstream does not cover. See [docs/ONBOARDING.md](../ONBOARDING.md). |
| `appinsights-instrumentation` | Pairs with `azure-integration-tester` | **Adopt (opt-in)** |

### 4.3 Workload-specific (opt-in per deployment)

`azure-compute`, `azure-kubernetes`, `azure-storage`, `azure-messaging`, `azure-kusto`, `azure-ai`, `azure-aigateway`, `microsoft-foundry`, `azure-hosted-copilot-sdk`, `airunway-aks-setup` → **all adopt as opt-in**, invoked by `azure-requirements-gatherer` / `azure-template-generator` based on workload.

## 5. Packaging & distribution

### 5.1 Options considered

| # | Approach | Pros | Cons |
|---|---|---|---|
| 1 | **Sibling plugin** — users install both `Azure/git-ape` and `microsoft/azure-skills` independently | Simplest; zero coupling; upstream drift is upstream's problem | User has to install two things; name collision must be resolved by rename; no declarative dependency |
| 2 | **Declared dependency** in `plugin.json` / `marketplace.json` | User experience is one install | Current Copilot plugin manifest schema does not appear to support plugin-level deps (verify before relying) |
| 3 | **Git submodule / vendor** upstream into `.github/plugins/azure-skills/` | Version pinning; offline usable | Drift maintenance burden; large surface area; duplicates upstream CI |
| 4 | **Marketplace pointer** — `marketplace.json` lists both plugins | Single marketplace; two independent installs | Requires Git-Ape marketplace to re-host the pointer; legal/branding review |

### 5.2 Proposed packaging plan

- **Phase 1 (this issue):** Option 1 — document `microsoft/azure-skills` as a recommended companion install in README and `docs/AZURE_MCP_SETUP.md`. Resolve the `azure-resource-visualizer` name collision by renaming the local skill. No manifest changes required for Phase 1.
- **Phase 2:** If/when Copilot plugin manifests support declarative dependencies, migrate to Option 2. Until then, `prereq-check` can verify whether the companion plugin is installed and prompt the user.
- **Phase 3 (optional):** Add multi-runtime manifests (`.claude-plugin`, `gemini-extension.json`, `.cursor-plugin`) to Git-Ape itself for runtime parity with upstream. Out of scope for this issue.

## 6. Runtime consistency

| Runtime | Git-Ape today | With upstream added | Risks |
|---|---|---|---|
| **VS Code Copilot Chat** | `@git-ape` agent, `az login` | Upstream installs via Azure MCP companion extension; skills appear alongside Git-Ape's | MCP config precedence if both register an `azure` MCP server; Git-Ape should defer to upstream's `.mcp.json` when present |
| **Copilot CLI** | `copilot plugin install Azure/git-ape` | `/plugin install azure@azure-skills` separately | Name collision on `/azure-resource-visualizer`; resolved by local rename |
| **Copilot Coding Agent (headless)** | `git-ape-*.yml` workflows use OIDC | Upstream skills' docs assume `az login` — need to verify they work under OIDC in a GitHub Actions runner | Upstream skill scripts may assume interactive prompts; test each adopted skill in a non-interactive runner before wiring into a workflow |

**Validation plan for Phase 2** (not executed in this PR):
1. Install `microsoft/azure-skills` in a VS Code workspace alongside Git-Ape; run a sample `@git-ape Deploy a Container App` flow and observe that `/azure-prepare` / `/azure-validate` are discoverable and callable.
2. In Copilot CLI: verify both plugins coexist; verify `/git-ape-resource-visualizer` (post-rename) does not collide.
3. In a CI runner with OIDC login, exec one upstream skill in non-interactive mode (candidate: `azure-validate`) and capture exit behavior.

## 7. Authentication & permissions

- Upstream README documents three auth paths (az CLI, service-principal env vars, managed identity). This is compatible with Git-Ape's OIDC-first posture — OIDC in GitHub Actions exchanges for an `az login` session before any skill runs.
- RBAC: Git-Ape's onboarding grants Contributor + User Access Administrator. Upstream skills should work within those permissions for the vast majority of operations. Deploy-time RBAC must continue to be enforced by Git-Ape's own role-assignment logic — do **not** let upstream skills silently escalate.
- **`entra-app-registration` co-existence**: validate that running upstream `entra-app-registration` after `git-ape-onboarding` is idempotent (i.e., it does not create duplicate App Registrations or federated credentials). Until verified, onboarding should not auto-invoke it.

## 8. Prerequisite & environment parity

- Add to `/prereq-check`:
  - Node.js ≥ 18 (for `npx` — upstream MCP startup)
  - `azd` (used by `azure-deploy`)
- Update [docs/CODESPACES.md](../CODESPACES.md) and `.devcontainer/` to pre-install Node 18 and `azd` when the companion plugin is expected.

## 9. Orchestration impact

- **Security gate stays blocking.** Adding `azure-compliance` is advisory only; it does not replace the mandatory Checkov / ARM-TTK / PSRule / Template Analyzer scans or `azure-security-analyzer`'s blocking gate.
- **Deployment-state contract is preserved.** Any upstream-delegated deploy action must update `state.json` / `metadata.json` in `.azure/deployments/<id>/`. If upstream `azure-deploy` does not, Git-Ape agents wrap the call and write state themselves.
- **Invocation syntax `/skill-name` is preserved.** Renaming local `azure-resource-visualizer` → `git-ape-resource-visualizer` is the only breaking change for existing users; call out in release notes.

## 10. Acceptance-criteria tracking (issue #13)

| Criterion | Status | Notes |
|---|---|---|
| Finalized overlap/gap matrix | ✅ Drafted (§4) | Awaiting maintainer sign-off |
| Adopt / embed / delegate decision | ✅ Drafted (§5.2) | Phase 1 = sibling plugin |
| PoC in 3 runtimes | ⬜ Deferred to Phase 2 | Plan in §6 |
| Auth verified (az login + OIDC) | ⬜ Deferred to Phase 2 | Plan in §6–7 |
| `azure-resource-visualizer` collision resolved | 📝 Proposed rename to `git-ape-resource-visualizer` | No code change yet |
| No regression in plan/deploy/verify/destroy | ✅ Design preserves contract (§9) | Validate during Phase 2 PoC |
| Updates to `plugin.json`, `marketplace.json`, README, prereq-check | ⬜ Deferred | Scoped into follow-up issues |
| Follow-up issues filed | ⬜ To be opened after this PR merges | See §11 |

## 11. Proposed follow-up child issues

1. **Rename `azure-resource-visualizer` → `git-ape-resource-visualizer`** (breaking; release-note-worthy).
2. **Deprecate `azure-role-selector` in favor of upstream `azure-rbac`** (ship a shim; remove in the next minor).
3. **Document `microsoft/azure-skills` as a recommended companion install** in README + `docs/AZURE_MCP_SETUP.md`.
4. **Extend `/prereq-check`** to verify Node 18 + `azd` and (optionally) detect the presence of `microsoft/azure-skills`.
5. **Phase 2 PoC: validate OIDC + headless execution** of `azure-prepare`, `azure-validate`, `azure-deploy`, `azure-diagnostics` inside `git-ape-*.yml`.
6. **Phase 2 PoC: evaluate `entra-app-registration`** against `git-ape-onboarding` for the App Registration / federated credential steps.
7. **Adopt `azure-diagnostics`** into the `git-ape-verify.yml` workflow on failure paths.
8. **Adopt opt-in workload skills** (`azure-kubernetes`, `azure-storage`, `azure-messaging`, `azure-compute`, `azure-ai`, etc.) — one issue per workload or a single umbrella.
9. **Phase 3 (optional): multi-runtime parity** — add `.claude-plugin`, `gemini-extension.json`, `.cursor-plugin` manifests to Git-Ape.

## 12. References

- Upstream plugin: [microsoft/azure-skills](https://github.com/microsoft/azure-skills)
- Upstream skills directory: [microsoft/azure-skills/tree/main/skills](https://github.com/microsoft/azure-skills/tree/main/skills)
- Git-Ape plugin manifest: [plugin.json](../../plugin.json)
- Git-Ape marketplace: [.github/plugin/marketplace.json](../../.github/plugin/marketplace.json)
- Git-Ape README: [README.md](../../README.md)
- Azure MCP setup: [docs/AZURE_MCP_SETUP.md](../AZURE_MCP_SETUP.md)
- Onboarding / OIDC: [docs/ONBOARDING.md](../ONBOARDING.md)
- Codespaces: [docs/CODESPACES.md](../CODESPACES.md)
