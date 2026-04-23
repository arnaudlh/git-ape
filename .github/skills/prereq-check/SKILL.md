---
name: prereq-check
description: "Check that all required CLI tools are installed, meet minimum versions, and have active auth sessions. Shows platform-specific install commands for anything missing."
argument-hint: "Run without arguments to check all prerequisites"
user-invocable: true
---

# Prerequisites Check

Validates the local environment has the CLI tools and auth sessions needed to run AutoCloud skills.

## When to Use

- Before first-time onboarding (`/autocloud-onboarding`)
- When any AutoCloud skill fails with a "command not found" error
- When switching machines or dev containers
- When a user asks "what do I need to install?"

## Required Tools

| Tool | Binary | Minimum Version | Purpose |
|------|--------|-----------------|---------|
| Azure CLI | `az` | 2.50 | Azure resource management, RBAC, deployments |
| GitHub CLI | `gh` | 2.0 | Repo secrets, environments, PR operations |
| jq | `jq` | 1.6 | JSON parsing in scripts and workflows |
| git | `git` | any | Version control (usually pre-installed) |
| Node.js | `node` / `npx` | 18 | Required by the `@microsoft/azure-skills` companion plugin (MCP servers launched via `npx`) |

## Recommended companion plugin

Git-Ape delegates RBAC, validation, readiness, diagnostics, and workload-specific skills to the [@microsoft/azure-skills](https://github.com/microsoft/azure-skills) companion plugin. It is **recommended, not required** — but most Git-Ape flows will prompt you to install it at the point of need. `/prereq-check` reports its presence as an advisory check (never blocking).

## Execution Playbook

Run the steps below in order. Present results as a table. Stop at the first blocking failure.

### Step 1: Detect Platform

```bash
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Platform: $OS / $ARCH"
```

Map the result for install instructions:
- `Darwin` → macOS
- `Linux` → Linux (check for `apt-get` vs `yum`/`dnf` to narrow distro)
- `MINGW*` / `MSYS*` → Windows (git-bash)

### Step 2: Check Each Tool

```bash
# --- az (Azure CLI) — required, minimum 2.50 ---
if command -v az &>/dev/null; then
  AZ_VER=$(az version --query '"azure-cli"' -o tsv 2>/dev/null)
  echo "az: $AZ_VER"
else
  echo "az: NOT FOUND"
fi

# --- gh (GitHub CLI) — required, minimum 2.0 ---
if command -v gh &>/dev/null; then
  GH_VER=$(gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "gh: $GH_VER"
else
  echo "gh: NOT FOUND"
fi

# --- jq — required, minimum 1.6 ---
if command -v jq &>/dev/null; then
  JQ_VER=$(jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[a-z]*')
  echo "jq: $JQ_VER"
else
  echo "jq: NOT FOUND"
fi

# --- git — required (usually pre-installed) ---
if command -v git &>/dev/null; then
  GIT_VER=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "git: $GIT_VER"
else
  echo "git: NOT FOUND"
fi

# --- node / npx — required, minimum 18 (for @microsoft/azure-skills MCP servers) ---
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>/dev/null | sed 's/^v//')
  echo "node: $NODE_VER"
else
  echo "node: NOT FOUND"
fi
if command -v npx &>/dev/null; then
  echo "npx: present"
else
  echo "npx: NOT FOUND (ships with Node.js ≥ 5.2)"
fi
```

### Step 3: Present Results

Show a table with pass/fail status:

| Tool | Status | Found Version | Minimum Required |
|------|--------|---------------|------------------|
| az   | ✅ / ❌ | x.y.z        | 2.50             |
| gh   | ✅ / ❌ | x.y.z        | 2.0              |
| jq   | ✅ / ❌ | x.y          | 1.6              |
| git  | ✅ / ❌ | x.y.z        | any              |
| node | ✅ / ❌ | x.y.z        | 18               |

Mark a tool ❌ if it is missing OR below the minimum version.

### Step 4: Show Install Commands (only if something is missing)

Show install commands only for missing or outdated tools, matching the detected platform.

**macOS (Homebrew):**
```bash
brew install azure-cli   # az
brew install gh           # GitHub CLI
brew install jq           # jq
brew install git          # git (if missing)
brew install node         # node + npx (for @microsoft/azure-skills)
```

**Ubuntu / Debian:**
```bash
# az — Microsoft repository
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# gh — GitHub repository
(type -p wget >/dev/null || sudo apt-get install wget -y) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt-get update && sudo apt-get install gh -y

# jq
sudo apt-get install -y jq

# Node.js 18+ (NodeSource)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**RHEL / Fedora:**
```bash
# az
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y azure-cli

# gh
sudo dnf install -y gh

# jq
sudo dnf install -y jq

# Node.js 20 (NodeSource)
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs
```

**Windows (PowerShell with winget):**
```powershell
winget install Microsoft.AzureCLI
winget install GitHub.cli
winget install jqlang.jq
winget install OpenJS.NodeJS.LTS
```

> **Windows note:** AutoCloud skills require a BASH shell. Install [Git for Windows](https://gitforwindows.org/) and use git-bash.

### Step 5: Check Auth Sessions

Only run this step if all tools passed Step 3.

```bash
# Azure CLI session
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "❌ Not logged in to Azure. Run: az login"
fi

# GitHub CLI session
gh auth status 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "❌ Not logged in to GitHub. Run: gh auth login"
fi
```

### Step 5b: Check companion plugin (advisory)

This check is informational only. Never block on its result.

```bash
# Detect @microsoft/azure-skills via Copilot CLI if available
if command -v copilot &>/dev/null; then
  # The plugin may appear in `copilot plugin list` as `azure`, `azure@azure-skills`,
  # or `microsoft/azure-skills` depending on how it was installed. Also check the
  # on-disk install path which is stable across install forms.
  INSTALLED=false
  if copilot plugin list 2>/dev/null | grep -qiE '(^|[[:space:]])azure([[:space:]]|@|$)|azure-skills|microsoft/azure-skills'; then
    INSTALLED=true
  fi
  if [[ -d "$HOME/.copilot/installed-plugins/_direct/microsoft--azure-skills" ]]; then
    INSTALLED=true
  fi
  if $INSTALLED; then
    echo "✅ companion @microsoft/azure-skills: installed"
  else
    echo "ℹ️  companion @microsoft/azure-skills: not installed"
    echo "    Install with:"
    echo "      /plugin marketplace add microsoft/azure-skills"
    echo "      /plugin install azure@azure-skills"
    echo "    See docs/AZURE_SKILLS_COMPANION.md for other runtimes."
  fi
else
  echo "ℹ️  copilot CLI not available — cannot auto-detect companion plugin."
  echo "    If you are on VS Code, install the Azure MCP Extension from the marketplace."
fi
```

### Step 6: Summary

Present a final verdict:

- **✅ READY** — All tools installed, versions OK, auth sessions active. Proceed with any AutoCloud skill.
- **⚠️ TOOLS MISSING** — List what to install. Do not proceed until resolved.
- **⚠️ AUTH MISSING** — Tools OK but user needs to run `az login` and/or `gh auth login`.

## Agent Behavior

1. Run Steps 1–5 by executing the commands in the terminal.
2. Present the results table and install commands (if needed).
3. Do NOT install anything automatically — show the commands and let the user run them.
4. If everything passes, tell the user they're ready and suggest next steps (e.g., `/autocloud-onboarding`).
