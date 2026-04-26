---
title: "Changelog"
sidebar_label: "Changelog"
sidebar_position: 99
description: "Git-Ape release notes and changelog"
---

# Changelog

## v0.0.2 (Current)

### Deploy Workflow — Rollback, Diagnostics, and PR Feedback

Hardened `git-ape-deploy.yml` with automated rollback, richer error diagnostics, and improved PR comment reporting.

#### Rollback on failure
- Capture pre-deploy stack state and previous template from git history before deploying
- On failure of an existing stack, redeploy the last-known-good template automatically
- On failure of a new stack, delete the partially-provisioned stack for a clean slate
- Surface rollback action and status in the deploy result PR comment

#### Deployment diagnostics
- Fetch underlying deployment operation errors on failure (`az deployment sub show` / `operation sub list`)
- Add structured log groups and timestamps throughout the workflow
- Enable verbose Azure CLI output during `az stack sub create`

#### PR comment improvements
- Post deploy results on both `push` (merge) and `issue_comment` (`/deploy`) triggers, not only `/deploy`
- Resolve the associated PR from the merge commit SHA on push events
- Include rollback summary and next-steps guidance in failure comments
- On merged-PR failures, open a tracking issue since merged PRs cannot be reopened
- On closed-but-unmerged PR failures, reopen the PR to surface the failure
- Move error output into a collapsible `<details>` block
- Pass large values via environment variables to avoid shell interpolation issues

---

## v0.0.1

Initial experimental release.

### Agents
- Git-Ape (main orchestrator)
- Azure Requirements Gatherer
- Azure Template Generator
- Azure Resource Deployer
- Azure Principal Architect
- Azure IaC Exporter
- Azure Policy Advisor
- Git-Ape Onboarding

### Skills
- 13 skills covering pre-deploy, post-deploy, and operations phases

### CI/CD Workflows
- `git-ape-plan.yml` — Validate & preview on PR
- `git-ape-deploy.yml` — Deploy on merge or `/deploy` command
- `git-ape-destroy.yml` — Tear down on merge with destroy-requested status
- `git-ape-verify.yml` — Manual setup verification
