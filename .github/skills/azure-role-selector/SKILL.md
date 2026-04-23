---
name: azure-role-selector
description: "DEPRECATED — replaced by `/azure-rbac` from @microsoft/azure-skills. This skill is a forwarding shim and will be removed in a future release. Invoke the upstream skill directly."
argument-hint: "Describe the permissions needed (e.g., 'read storage blobs')"
user-invocable: true
---

# Azure Role Selector — DEPRECATED

> **⚠️ Deprecated in Git-Ape v0.1.** This skill has been replaced by the upstream `/azure-rbac` skill from [@microsoft/azure-skills](https://github.com/microsoft/azure-skills). It is scheduled for removal in the next minor release.

## Procedure

1. **Check for upstream availability.**
   - If `@microsoft/azure-skills` is installed, invoke `/azure-rbac` with the same arguments and return its output.
   - Confirm with the user that they received an `azure-rbac`-backed response.

2. **If upstream is not installed.**
   - Tell the user:
     > The `azure-role-selector` skill has been deprecated in favor of `/azure-rbac` from the upstream [@microsoft/azure-skills](https://github.com/microsoft/azure-skills) plugin.
     >
     > Install the companion plugin to get up-to-date RBAC guidance:
     >
     > ```bash
     > # Copilot CLI
     > /plugin marketplace add microsoft/azure-skills
     > /plugin install azure@azure-skills
     > ```
     >
     > See `docs/investigations/azure-skills-plugin.md` for background.
   - Do **not** fabricate role recommendations locally. Stop and wait for the user to install the companion plugin or provide an alternative path.

## Why this was deprecated

The upstream `azure-rbac` skill is a strict superset of this skill's capabilities, is actively maintained by Microsoft, and covers both built-in role lookup and custom role definition authoring. Shipping a duplicate implementation in Git-Ape risked drift and conflicting guidance.

## Migration for agent authors

Replace any agent instruction that reads:

> **Invoke skill:** `/azure-role-selector`

with:

> **Invoke skill:** `/azure-rbac` (from `@microsoft/azure-skills`; if not installed, prompt the user to install the companion plugin).

## References

- Upstream skill: [microsoft/azure-skills/skills/azure-rbac](https://github.com/microsoft/azure-skills/tree/main/skills/azure-rbac)
- Investigation report: `docs/investigations/azure-skills-plugin.md`
- Companion install: `docs/AZURE_SKILLS_COMPANION.md`
