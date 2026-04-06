---
name: git-ape-onboarding
description: "Onboard a repository, Azure subscription(s), and user identity for Git-Ape CI/CD using a skill-driven CLI playbook. Use for first-time setup of OIDC, federated credentials, RBAC, GitHub environments, and required secrets."
argument-hint: "GitHub repo URL, subscription target(s), and onboarding mode (single or multi-environment)"
user-invocable: true
---

# Git-Ape Onboarding

Use this skill to bootstrap a repository for Git-Ape deployments by executing the onboarding workflow directly from Copilot Chat.

This skill is the source of truth for onboarding behavior. Do not depend on a standalone repository script for setup logic.

## When to Use

- First-time setup of a repository for Git-Ape
- New subscription onboarding (single environment)
- Multi-environment onboarding (dev/staging/prod across different subscriptions)
- New user handoff where OIDC, RBAC, and GitHub environments must be created

## What It Configures

This skill configures:

1. Entra ID App Registration and service principal (or reuses existing)
2. OIDC federated credentials for GitHub Actions
3. RBAC role assignment(s) on subscription scope
4. GitHub environments (`azure-deploy*`, `azure-destroy`)
5. Required GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)

## Prerequisites

Verify before execution:

```bash
command -v az
command -v gh
command -v jq
az account show
gh auth status
```

If auth is missing, stop and ask the user to run:

```bash
az login
gh auth login
```

## Execution Modes

### Interactive (recommended for first-time use)

Invoke the skill from chat and let the agent gather missing parameters:

```text
/git-ape-onboarding
```

### Parameterized single environment

```text
/git-ape-onboarding onboard https://github.com/org/repo on subscription 00000000-0000-0000-0000-000000000000 with Contributor
```

### Parameterized multi-environment

```text
/git-ape-onboarding onboard https://github.com/org/repo with dev on 11111111-1111-1111-1111-111111111111 as Contributor, staging on 22222222-2222-2222-2222-222222222222 as Contributor, prod on 33333333-3333-3333-3333-333333333333 as Contributor+UserAccessAdministrator
```

## Command Playbook

When the agent executes this skill, it should run the equivalent Azure and GitHub CLI commands directly in this order:

1. Validate prerequisites and current auth context.
2. Resolve repo metadata:
```bash
gh repo view <org>/<repo>
gh api repos/<org>/<repo> --jq '{repo_id: .id, owner_id: .owner.id}'
gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'
```
3. Create or reuse the Entra app registration and service principal:
```bash
CLIENT_ID=$(az ad app create --display-name "$SP_NAME" --query appId -o tsv)
az ad sp create --id "$CLIENT_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)
OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
```
4. Build the OIDC subject prefix:
```bash
# default format
OIDC_PREFIX="repo:<org>/<repo>"

# if org customization returns false
OIDC_PREFIX="repository_owner_id:<OWNER_ID>:repository_id:<REPO_ID>"
```
5. Create federated credentials for `main`, `pull_request`, `azure-deploy*`, and `azure-destroy`.
6. Assign RBAC on each target subscription.
7. Set GitHub repo or environment secrets.
8. Create GitHub environments and branch policies when permissions allow.
9. Verify federated credentials, role assignments, and secrets.

## Safe-Execution Rules

1. Echo target repository and subscription(s) before execution.
2. Require explicit user confirmation before running onboarding.
3. Never print secret values in chat output.
4. Summarize what was created or updated (app registration, federated credentials, role assignments, GitHub environments).
5. If onboarding fails, surface the failing step and command context, then stop.

## Suggested Agent Flow

1. Confirm target repo URL, onboarding mode, and role model.
2. Validate prerequisites and current Azure/GitHub auth context.
3. Ask for final confirmation.
4. Execute the required Azure CLI and GitHub CLI commands directly from this playbook.
5. Summarize outcome and suggest verification commands.

## Known Gotchas

### GitHub Org Custom OIDC Subject Template (e.g. Azure org)

Some GitHub organizations (notably the `Azure` org) override the default OIDC subject
claim template to use **numeric ID-based** subjects instead of name-based ones.

The skill auto-detects this by calling:
```bash
gh api "orgs/{org}/actions/oidc/customization/sub" --jq ".use_default"
```
- Returns `true` → standard format: `repo:Azure/git-ape-private:pull_request`
- Returns `false` → ID format: `repository_owner_id:6844498:repository_id:1184905165:pull_request`

If OIDC login fails with `AADSTS700213: No matching federated identity record`, the
federated credential subjects don't match what GitHub is presenting. Fix by re-running
onboarding (the skill will auto-detect and use the correct format), or manually updating
existing credentials:
```bash
# Get repo/owner IDs
gh api repos/Azure/git-ape-private --jq '{repo_id: .id, owner_id: .owner.id}'

# Update each federated credential with correct subject
az ad app federated-credential update \
  --id <APP_OBJECT_ID> \
  --federated-credential-id <CRED_ID> \
  --parameters '{"subject":"repository_owner_id:<OWNER_ID>:repository_id:<REPO_ID>:pull_request"}'
```

### Disabled Subscriptions

Azure subscriptions in a `Disabled` state are read-only — RBAC assignments will fail.
Verify subscription state before onboarding:
```bash
az account show --subscription <SUB_ID> --query "{name:name,state:state}" -o table
# Test write access:
az group list --subscription <SUB_ID> --query "length(@)" -o tsv
```

## Verification Commands

```bash
# Azure context
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table

# GitHub auth
gh auth status

# Validate app federated credentials — check subjects match org OIDC format
az ad app federated-credential list --id <APP_OBJECT_ID> -o json | jq -r '.[] | "\(.name): \(.subject)"'

# Check GitHub org OIDC subject template (true = name-based, false = ID-based)
gh api orgs/<ORG>/actions/oidc/customization/sub --jq '.use_default'

# Get repo and owner numeric IDs (needed for ID-based subject construction)
gh api repos/<ORG>/<REPO> --jq '{repo_id: .id, owner_id: .owner.id}'

# Validate role assignments for SP (replace principal object id)
az role assignment list --assignee-object-id <SP_OBJECT_ID> --all -o table
```