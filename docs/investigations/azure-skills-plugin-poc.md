# POC: Git-Ape ↔ `@microsoft/azure-skills` delegation

This document demonstrates how Git-Ape agents delegate to the companion plugin's skills. It accompanies the rename/shim/manifest changes shipped for [Azure/git-ape#13](https://github.com/Azure/git-ape/issues/13).

## Prerequisites

1. Git-Ape installed (`copilot plugin install Azure/git-ape`).
2. Companion installed (`copilot plugin install azure@azure-skills`). See [docs/AZURE_SKILLS_COMPANION.md](AZURE_SKILLS_COMPANION.md).
3. Node.js 18+ on PATH (`node --version`).
4. `az login` completed.

Run `/prereq-check` first — it now reports Node 18+ and advisory-checks the companion plugin.

## Scenario A — RBAC delegation (replaces `/azure-role-selector`)

**Before this change:**

```
User: @git-ape what role does my Function App need to read blobs from storage?
@git-ape: Invoking /azure-role-selector ...
         → Storage Blob Data Reader (built-in)
```

**After this change:**

```
User: @git-ape what role does my Function App need to read blobs from storage?
@git-ape: Invoking /azure-rbac (from @microsoft/azure-skills) ...
         → Storage Blob Data Reader (built-in)
         → Ready-to-use CLI + ARM snippet
```

If the companion is not installed, Git-Ape responds:

```
@git-ape: The /azure-rbac skill is provided by @microsoft/azure-skills
          which is not installed in this workspace.
          Install it with:
            /plugin install azure@azure-skills
          Details: docs/AZURE_SKILLS_COMPANION.md
```

## Scenario B — Architecture visualization (rename)

**Before:**

```
User: @git-ape show me the live architecture of deployment abc-123
@git-ape: Invoking /azure-resource-visualizer ...  ← collides with upstream in v0.1+
```

**After:**

```
User: @git-ape show me the live architecture of deployment abc-123
@git-ape: Invoking /git-ape-resource-visualizer abc-123 ...
         → Reads .azure/deployments/abc-123/state.json
         → Queries live Azure for current config
         → Emits Mermaid diagram to .azure/deployments/abc-123/architecture-live.md
```

For a **non-Git-Ape** resource group, the upstream skill is used directly:

```
User: /azure-resource-visualizer my-existing-rg
(handled entirely by @microsoft/azure-skills)
```

## Scenario C — Pre-deploy validation layering

Git-Ape's mandatory scans (Checkov / ARM-TTK / PSRule / Template Analyzer) remain the blocking gate. The companion's `/azure-validate` runs as an advisory secondary pass:

```
Stage 2 (Template & Analysis)
  ├─ Mandatory scans ............. Checkov, ARM-TTK, PSRule, Template Analyzer
  ├─ /azure-security-analyzer .... per-resource security gate (blocking)
  ├─ /azure-policy-advisor ....... policy compliance (advisory)
  └─ /azure-validate ............. upstream advisory validation ← NEW
```

`/azure-validate` findings are surfaced in the PR plan comment but never downgrade or replace the blocking gate.

## Scenario D — Post-deploy diagnostics on failure

`git-ape-verify.yml` on integration-test failure now invokes `/azure-diagnostics`:

```
Stage 4 (Validate)
  ├─ /azure-integration-tester ... smoke tests
  └─ if fail → /azure-diagnostics (from @microsoft/azure-skills) ← NEW
       → Structured diagnosis posted as PR comment
```

## Verifying the POC locally

```bash
# 1. Confirm rename
test -d .github/skills/git-ape-resource-visualizer && echo OK
test ! -d .github/skills/azure-resource-visualizer && echo OK

# 2. Confirm shim
grep -q "DEPRECATED" .github/skills/azure-role-selector/SKILL.md && echo OK

# 3. Confirm manifest declares the companion
jq '.recommends[0].source' plugin.json        # → "microsoft/azure-skills"
jq '.plugins | length' .github/plugin/marketplace.json   # → 2

# 4. Confirm prereq-check covers Node 18
grep -q "node" .github/skills/prereq-check/SKILL.md && echo OK
```

## Scope & caveats

- **Schema disclaimer:** the `recommends[]` field in `plugin.json` and the `upstream` / `required` flags in `marketplace.json` are proposed extensions. Current Copilot plugin tooling may ignore unknown fields (safe) but will not enforce installation (expected). Option 1 (companion install docs) is the only non-speculative path today. Options 2 and 4 are forward-looking and documented for when the schema gains declarative-dependency support.
- **No auto-install:** Git-Ape never installs the companion plugin automatically. The user runs the install command.
- **Runtime parity:** this POC has been validated **in documentation form only**. Full three-runtime validation (VS Code / Copilot CLI / Coding Agent headless) is tracked as a follow-up per the investigation report.
