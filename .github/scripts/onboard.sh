#!/bin/bash
# AutoCloud Onboarding Script
# Sets up everything needed to use AutoCloud with a GitHub repository:
#   1. Creates (or reuses) an Entra ID App Registration
#   2. Configures OIDC federated credentials for GitHub Actions
#   3. Assigns RBAC roles on the target subscription(s)
#   4. Creates GitHub environments with per-environment secrets
#   5. Sets required GitHub secrets (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID)
#
# Supports two modes:
#   - Single environment: one Azure subscription, repo-level secrets
#   - Multi-environment: separate GitHub environments (dev/staging/prod) each
#     targeting a different Azure subscription with environment-level secrets
#
# Prerequisites:
#   - Azure CLI (az) installed and logged in with Owner/User Access Administrator on the subscription
#   - GitHub CLI (gh) installed and authenticated
#   - jq installed

set -euo pipefail

# ──────────────────────────────────────────────────────
# Colors
# ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
info() { echo -e "${BLUE}ℹ${NC} $*"; }
step() { echo -e "\n${BOLD}${CYAN}── $* ──${NC}\n"; }

# ──────────────────────────────────────────────────────
# Prerequisite checks
# ──────────────────────────────────────────────────────
check_prerequisites() {
  step "Checking prerequisites"

  local missing=0

  if ! command -v az &>/dev/null; then
    err "Azure CLI (az) not found. Install: https://docs.microsoft.com/cli/azure/install-azure-cli"
    missing=1
  else
    log "Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv 2>/dev/null)"
  fi

  if ! command -v gh &>/dev/null; then
    err "GitHub CLI (gh) not found. Install: https://cli.github.com"
    missing=1
  else
    log "GitHub CLI found: $(gh --version | head -1)"
  fi

  if ! command -v jq &>/dev/null; then
    err "jq not found. Install: brew install jq"
    missing=1
  else
    log "jq found"
  fi

  # Check Azure login
  if ! az account show &>/dev/null; then
    err "Not logged in to Azure. Run: az login"
    missing=1
  else
    local az_user
    az_user=$(az account show --query "user.name" -o tsv)
    log "Azure CLI authenticated as: $az_user"
  fi

  # Check GitHub login
  if ! gh auth status &>/dev/null 2>&1; then
    err "Not logged in to GitHub CLI. Run: gh auth login"
    missing=1
  else
    local gh_user
    gh_user=$(gh api user --jq '.login' 2>/dev/null)
    log "GitHub CLI authenticated as: $gh_user"
  fi

  if [[ $missing -ne 0 ]]; then
    err "Missing prerequisites. Fix the issues above and re-run."
    exit 1
  fi
}

# ──────────────────────────────────────────────────────
# Gather inputs (interactive)
# ──────────────────────────────────────────────────────

# Prompt for RBAC role and return the choice
prompt_rbac_role() {
  local role_var="$1"
  echo -e "\n${BOLD}RBAC role to assign${NC} (default: Contributor):"
  echo "  1. Contributor (create/modify/delete resources)"
  echo "  2. Contributor + User Access Administrator (also manage RBAC)"
  echo "  3. Custom (enter role name)"
  read -r ROLE_CHOICE
  case "${ROLE_CHOICE:-1}" in
    1) eval "$role_var=Contributor" ;;
    2) eval "$role_var=Contributor+UserAccessAdministrator" ;;
    3) echo "Enter custom role name:"; read -r custom_role; eval "$role_var=\$custom_role" ;;
    *) eval "$role_var=Contributor" ;;
  esac
}

gather_inputs() {
  step "Gathering configuration"

  # GitHub repo URL
  if [[ -z "${GITHUB_REPO_URL:-}" ]]; then
    echo -e "${BOLD}GitHub repository URL${NC} (e.g. https://github.com/org/repo):"
    read -r GITHUB_REPO_URL
  fi

  # Validate and parse the URL — accept only github.com URLs with org/repo
  if [[ ! "$GITHUB_REPO_URL" =~ ^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/?$ ]]; then
    err "Invalid GitHub repo URL. Expected format: https://github.com/{org}/{repo}"
    exit 1
  fi

  GITHUB_REPO_URL="${GITHUB_REPO_URL%/}" # strip trailing slash
  REPO_FULL=$(echo "$GITHUB_REPO_URL" | sed 's|https://github.com/||')
  REPO_ORG=$(echo "$REPO_FULL" | cut -d/ -f1)
  REPO_NAME=$(echo "$REPO_FULL" | cut -d/ -f2)
  log "Repository: $REPO_FULL"

  # Verify repo exists and user has access
  if ! gh repo view "$REPO_FULL" &>/dev/null; then
    err "Cannot access repository $REPO_FULL. Check the URL and your permissions."
    exit 1
  fi
  log "Repository access verified"

  # Service principal name
  if [[ -z "${SP_NAME:-}" ]]; then
    DEFAULT_SP="sp-autocloud-${REPO_NAME}"
    echo -e "\n${BOLD}Entra ID App Registration name${NC} (default: ${DEFAULT_SP}):"
    read -r SP_NAME
    SP_NAME="${SP_NAME:-$DEFAULT_SP}"
  fi
  log "App Registration name: $SP_NAME"

  # ── Multi-environment setup ─────────────────────────
  # ENVIRONMENTS is an array of "name|subscription_id|rbac_role" entries
  ENVIRONMENTS=()
  MULTI_ENV=false

  # Non-interactive: parse AUTOCLOUD_ENVIRONMENTS env var (comma-separated "name|sub|role" entries)
  if [[ -n "${AUTOCLOUD_ENVIRONMENTS:-}" ]]; then
    MULTI_ENV=true
    IFS=',' read -ra ENV_SPECS <<< "$AUTOCLOUD_ENVIRONMENTS"
    for SPEC in "${ENV_SPECS[@]}"; do
      # Validate format: name|subscription_id|role
      if [[ ! "$SPEC" =~ ^[a-z0-9-]+\|[a-f0-9-]+\|.+$ ]]; then
        err "Invalid environment spec: '$SPEC'. Expected format: name|subscription-id|rbac-role"
        exit 1
      fi
      ENVIRONMENTS+=("$SPEC")
      IFS='|' read -r _N _S _R <<< "$SPEC"
      log "Environment '$_N' → Subscription $_S ($_R)"
    done
  elif [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
    echo ""
    echo -e "${BOLD}Do you want to configure multiple deployment environments?${NC}"
    echo "  This lets you target different Azure subscriptions per environment"
    echo "  (e.g. dev → Sub-A, staging → Sub-B, prod → Sub-C)"
    echo -e "  (y/N):"
    read -r MULTI_ENV_CHOICE
    MULTI_ENV_CHOICE_LC=$(echo "$MULTI_ENV_CHOICE" | tr '[:upper:]' '[:lower:]')

    if [[ "$MULTI_ENV_CHOICE_LC" == "y" || "$MULTI_ENV_CHOICE_LC" == "yes" ]]; then
      MULTI_ENV=true
      gather_environments
    fi
  fi

  if [[ "$MULTI_ENV" == false ]]; then
    # Single-environment mode (backward compatible)
    if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
      CURRENT_SUB=$(az account show --query id -o tsv)
      CURRENT_SUB_NAME=$(az account show --query name -o tsv)
      echo -e "\n${BOLD}Azure Subscription ID${NC} (default: $CURRENT_SUB — $CURRENT_SUB_NAME):"
      read -r SUBSCRIPTION_ID
      SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$CURRENT_SUB}"
    fi
    log "Subscription: $SUBSCRIPTION_ID"

    # RBAC role
    if [[ -z "${RBAC_ROLE:-}" ]]; then
      prompt_rbac_role RBAC_ROLE
    fi
    log "RBAC role: $RBAC_ROLE"
  fi

  # ── Confirmation ────────────────────────────────────
  echo ""
  echo -e "${BOLD}Configuration Summary${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "  Repository:       ${CYAN}$REPO_FULL${NC}"
  echo -e "  App Registration: ${CYAN}$SP_NAME${NC}"

  if [[ "$MULTI_ENV" == true ]]; then
    echo -e "  Mode:             ${CYAN}Multi-environment${NC}"
    echo ""
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME ENV_SUB ENV_ROLE <<< "$ENV_ENTRY"
      echo -e "  ${BOLD}Environment: ${CYAN}$ENV_NAME${NC}"
      echo -e "    Subscription:   ${CYAN}$ENV_SUB${NC}"
      echo -e "    RBAC role:      ${CYAN}$ENV_ROLE${NC}"
      echo -e "    GitHub env:     ${CYAN}azure-deploy-${ENV_NAME}${NC}"
    done
  else
    echo -e "  Mode:             ${CYAN}Single environment${NC}"
    echo -e "  Subscription:     ${CYAN}$SUBSCRIPTION_ID${NC}"
    echo -e "  RBAC role:        ${CYAN}$RBAC_ROLE${NC}"
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e "${BOLD}Proceed?${NC} (y/N)"
  read -r CONFIRM
  CONFIRM_LC=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  if [[ "$CONFIRM_LC" != "y" && "$CONFIRM_LC" != "yes" ]]; then
    info "Aborted."
    exit 0
  fi
}

# ──────────────────────────────────────────────────────
# Gather multi-environment definitions
# ──────────────────────────────────────────────────────
gather_environments() {
  echo ""
  echo -e "${BOLD}How many environments?${NC} (default: 3 for dev/staging/prod):"
  read -r ENV_COUNT
  ENV_COUNT="${ENV_COUNT:-3}"

  # Validate numeric input
  if ! [[ "$ENV_COUNT" =~ ^[0-9]+$ ]] || [[ "$ENV_COUNT" -lt 1 ]] || [[ "$ENV_COUNT" -gt 10 ]]; then
    err "Invalid environment count. Enter a number between 1 and 10."
    exit 1
  fi

  local DEFAULT_NAMES=("dev" "staging" "prod")
  local CURRENT_SUB
  local CURRENT_SUB_NAME
  CURRENT_SUB=$(az account show --query id -o tsv)
  CURRENT_SUB_NAME=$(az account show --query name -o tsv)

  for ((i = 1; i <= ENV_COUNT; i++)); do
    echo ""
    echo -e "${BOLD}${CYAN}── Environment $i of $ENV_COUNT ──${NC}"

    # Environment name
    local DEFAULT_NAME="${DEFAULT_NAMES[$((i-1))]:-env$i}"
    echo -e "\n${BOLD}Environment name${NC} (default: $DEFAULT_NAME):"
    read -r ENV_NAME
    ENV_NAME="${ENV_NAME:-$DEFAULT_NAME}"

    # Validate environment name (lowercase alphanumeric + hyphens)
    if [[ ! "$ENV_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
      err "Invalid environment name '$ENV_NAME'. Use lowercase alphanumeric characters and hyphens."
      exit 1
    fi

    # Subscription for this environment
    echo -e "${BOLD}Azure Subscription ID for '$ENV_NAME'${NC} (default: $CURRENT_SUB — $CURRENT_SUB_NAME):"
    read -r ENV_SUB
    ENV_SUB="${ENV_SUB:-$CURRENT_SUB}"

    # RBAC role for this environment
    local ENV_ROLE
    prompt_rbac_role ENV_ROLE

    ENVIRONMENTS+=("${ENV_NAME}|${ENV_SUB}|${ENV_ROLE}")
    log "Environment '$ENV_NAME' → Subscription $ENV_SUB ($ENV_ROLE)"
  done
}

# ──────────────────────────────────────────────────────
# Step 1: Create or find the Entra ID App Registration
# ──────────────────────────────────────────────────────
create_app_registration() {
  step "Step 1: Entra ID App Registration"

  # Check if app already exists
  EXISTING_APP_ID=$(az ad app list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

  if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" != "None" ]]; then
    warn "App Registration '$SP_NAME' already exists (Client ID: $EXISTING_APP_ID)"
    echo -e "  Reuse existing? (Y/n)"
    read -r REUSE
    REUSE_LC=$(echo "$REUSE" | tr '[:upper:]' '[:lower:]')
    if [[ "$REUSE_LC" == "n" || "$REUSE_LC" == "no" ]]; then
      err "Aborting. Choose a different name or delete the existing app first."
      exit 1
    fi
    CLIENT_ID="$EXISTING_APP_ID"
    log "Reusing existing App Registration: $CLIENT_ID"
  else
    info "Creating App Registration: $SP_NAME"
    CLIENT_ID=$(az ad app create \
      --display-name "$SP_NAME" \
      --query appId -o tsv)
    log "App Registration created: $CLIENT_ID"

    # Create a service principal for the app
    info "Creating Service Principal for the app..."
    az ad sp create --id "$CLIENT_ID" -o none 2>/dev/null || true
    log "Service Principal created"
  fi

  # Get tenant ID
  TENANT_ID=$(az account show --query tenantId -o tsv)
  log "Tenant ID: $TENANT_ID"
}

# ──────────────────────────────────────────────────────
# Step 2: Configure OIDC federated credentials
# ──────────────────────────────────────────────────────

# Helper: create a single federated credential (idempotent)
create_federated_credential() {
  local OBJECT_ID="$1"
  local CRED_NAME="$2"
  local SUBJECT="$3"
  local DESCRIPTION="$4"

  # Check if credential already exists
  local EXISTING
  EXISTING=$(az ad app federated-credential list --id "$OBJECT_ID" \
    --query "[?name=='$CRED_NAME'].name" -o tsv 2>/dev/null || echo "")

  if [[ -n "$EXISTING" ]]; then
    warn "Federated credential '$CRED_NAME' already exists, skipping"
    return 0
  fi

  info "Creating federated credential: $CRED_NAME ($DESCRIPTION)"
  az ad app federated-credential create --id "$OBJECT_ID" \
    --parameters "{
      \"name\": \"$CRED_NAME\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$SUBJECT\",
      \"description\": \"$DESCRIPTION\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" -o none

  log "Created: $CRED_NAME"
}

configure_oidc() {
  step "Step 2: OIDC Federated Credentials"

  local OBJECT_ID
  OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)

  # Common credentials: main branch and pull requests
  create_federated_credential "$OBJECT_ID" \
    "fc-${REPO_NAME}-main" \
    "repo:${REPO_FULL}:ref:refs/heads/main" \
    "Main branch deployments"

  create_federated_credential "$OBJECT_ID" \
    "fc-${REPO_NAME}-pr" \
    "repo:${REPO_FULL}:pull_request" \
    "Pull request validation"

  if [[ "$MULTI_ENV" == true ]]; then
    # Per-environment federated credentials
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME _ENV_SUB _ENV_ROLE <<< "$ENV_ENTRY"

      create_federated_credential "$OBJECT_ID" \
        "fc-${REPO_NAME}-env-deploy-${ENV_NAME}" \
        "repo:${REPO_FULL}:environment:azure-deploy-${ENV_NAME}" \
        "Deploy environment (${ENV_NAME})"
    done

    # Destroy environment (shared across all envs)
    create_federated_credential "$OBJECT_ID" \
      "fc-${REPO_NAME}-env-destroy" \
      "repo:${REPO_FULL}:environment:azure-destroy" \
      "Destroy environment"
  else
    # Single-environment mode (backward compatible)
    create_federated_credential "$OBJECT_ID" \
      "fc-${REPO_NAME}-env-deploy" \
      "repo:${REPO_FULL}:environment:azure-deploy" \
      "Deploy environment"

    create_federated_credential "$OBJECT_ID" \
      "fc-${REPO_NAME}-env-destroy" \
      "repo:${REPO_FULL}:environment:azure-destroy" \
      "Destroy environment"
  fi
}

# ──────────────────────────────────────────────────────
# Step 3: Assign RBAC roles on the subscription
# ──────────────────────────────────────────────────────

# Helper: assign RBAC roles for a given subscription + role spec
assign_rbac_for_subscription() {
  local SP_OBJECT_ID="$1"
  local SUB_ID="$2"
  local ROLE_SPEC="$3"  # e.g. "Contributor+UserAccessAdministrator"
  local ENV_LABEL="${4:-}"  # optional label for logging

  local SCOPE="/subscriptions/$SUB_ID"

  IFS='+' read -ra ROLES <<< "$ROLE_SPEC"

  for ROLE in "${ROLES[@]}"; do
    local EXISTING
    EXISTING=$(az role assignment list \
      --assignee "$SP_OBJECT_ID" \
      --role "$ROLE" \
      --scope "$SCOPE" \
      --query "length(@)" -o tsv 2>/dev/null || echo "0")

    if [[ "$EXISTING" -gt 0 ]]; then
      warn "Role '$ROLE' already assigned on $SUB_ID${ENV_LABEL:+ ($ENV_LABEL)}, skipping"
      continue
    fi

    info "Assigning role: $ROLE on subscription $SUB_ID${ENV_LABEL:+ ($ENV_LABEL)}"
    az role assignment create \
      --assignee-object-id "$SP_OBJECT_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "$ROLE" \
      --scope "$SCOPE" -o none

    log "Role assigned: $ROLE on $SUB_ID${ENV_LABEL:+ ($ENV_LABEL)}"
  done
}

assign_rbac() {
  step "Step 3: RBAC Role Assignment"

  local SP_OBJECT_ID
  SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)

  if [[ "$MULTI_ENV" == true ]]; then
    # Collect unique subscriptions to avoid duplicate assignments
    local SEEN_SUBS=()

    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME ENV_SUB ENV_ROLE <<< "$ENV_ENTRY"
      assign_rbac_for_subscription "$SP_OBJECT_ID" "$ENV_SUB" "$ENV_ROLE" "$ENV_NAME"
    done
  else
    assign_rbac_for_subscription "$SP_OBJECT_ID" "$SUBSCRIPTION_ID" "$RBAC_ROLE"
  fi
}

# ──────────────────────────────────────────────────────
# Step 4: Configure GitHub repository
# ──────────────────────────────────────────────────────

# Helper: Create a single GitHub environment with branch policy
create_github_environment() {
  local ENV_GH_NAME="$1"
  local BRANCH_POLICY="$2"  # "main" to restrict to main, "none" for no restriction

  if [[ "$BRANCH_POLICY" == "main" ]]; then
    gh api -X PUT "repos/$REPO_FULL/environments/$ENV_GH_NAME" \
      --input - <<EOF 2>/dev/null || warn "Could not create '$ENV_GH_NAME' environment (may require admin access)"
{
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
    # Add main branch as allowed deployment branch
    gh api -X POST "repos/$REPO_FULL/environments/$ENV_GH_NAME/deployment-branch-policies" \
      --input - <<EOF 2>/dev/null || true
{
  "name": "main",
  "type": "branch"
}
EOF
    log "Environment created: $ENV_GH_NAME (branch: main)"
  else
    gh api -X PUT "repos/$REPO_FULL/environments/$ENV_GH_NAME" \
      --input - <<EOF 2>/dev/null || warn "Could not create '$ENV_GH_NAME' environment (may require admin access)"
{
  "deployment_branch_policy": null
}
EOF
    log "Environment created: $ENV_GH_NAME"
  fi
}

# Helper: Set a secret on a GitHub environment
set_environment_secret() {
  local ENV_GH_NAME="$1"
  local SECRET_NAME="$2"
  local SECRET_VALUE="$3"

  gh secret set "$SECRET_NAME" \
    --repo "$REPO_FULL" \
    --env "$ENV_GH_NAME" \
    --body "$SECRET_VALUE"
}

configure_github() {
  step "Step 4: GitHub Repository Configuration"

  if [[ "$MULTI_ENV" == true ]]; then
    # ── Multi-environment mode ──────────────────────────
    # Repo-level secrets: only CLIENT_ID and TENANT_ID (shared across envs)
    info "Setting repo-level secrets (shared)..."
    echo "$CLIENT_ID" | gh secret set AZURE_CLIENT_ID -R "$REPO_FULL"
    log "Repo secret set: AZURE_CLIENT_ID"
    echo "$TENANT_ID" | gh secret set AZURE_TENANT_ID -R "$REPO_FULL"
    log "Repo secret set: AZURE_TENANT_ID"

    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME ENV_SUB ENV_ROLE <<< "$ENV_ENTRY"
      local GH_ENV_NAME="azure-deploy-${ENV_NAME}"

      info "Configuring GitHub environment: $GH_ENV_NAME"

      # Create the environment
      create_github_environment "$GH_ENV_NAME" "main"

      # Set environment-level secrets (subscription is per-env)
      set_environment_secret "$GH_ENV_NAME" "AZURE_SUBSCRIPTION_ID" "$ENV_SUB"
      log "Environment secret set: AZURE_SUBSCRIPTION_ID on $GH_ENV_NAME"

      # Optionally set CLIENT_ID and TENANT_ID at env level too
      # (allows overriding per-env if different app registrations are needed later)
      set_environment_secret "$GH_ENV_NAME" "AZURE_CLIENT_ID" "$CLIENT_ID"
      set_environment_secret "$GH_ENV_NAME" "AZURE_TENANT_ID" "$TENANT_ID"
      log "Environment secrets set: AZURE_CLIENT_ID, AZURE_TENANT_ID on $GH_ENV_NAME"
    done

    # Destroy environment (shared)
    info "Creating shared destroy environment..."
    create_github_environment "azure-destroy" "none"

    # Set a default subscription on destroy env (can be overridden per /destroy command)
    IFS='|' read -r _FIRST_NAME FIRST_SUB _FIRST_ROLE <<< "${ENVIRONMENTS[0]}"
    set_environment_secret "azure-destroy" "AZURE_SUBSCRIPTION_ID" "$FIRST_SUB"
    set_environment_secret "azure-destroy" "AZURE_CLIENT_ID" "$CLIENT_ID"
    set_environment_secret "azure-destroy" "AZURE_TENANT_ID" "$TENANT_ID"
    log "Destroy environment configured with default subscription"

  else
    # ── Single-environment mode (backward compatible) ──
    info "Setting GitHub Actions secrets..."

    echo "$CLIENT_ID" | gh secret set AZURE_CLIENT_ID -R "$REPO_FULL"
    log "Secret set: AZURE_CLIENT_ID"

    echo "$TENANT_ID" | gh secret set AZURE_TENANT_ID -R "$REPO_FULL"
    log "Secret set: AZURE_TENANT_ID"

    echo "$SUBSCRIPTION_ID" | gh secret set AZURE_SUBSCRIPTION_ID -R "$REPO_FULL"
    log "Secret set: AZURE_SUBSCRIPTION_ID"

    # Create GitHub environments
    info "Creating GitHub environments..."
    create_github_environment "azure-deploy" "main"
    create_github_environment "azure-destroy" "none"
  fi
}

# ──────────────────────────────────────────────────────
# Step 5: Verify setup
# ──────────────────────────────────────────────────────
verify_setup() {
  step "Step 5: Verification"

  local errors=0

  # Verify app registration
  local APP_CHECK
  APP_CHECK=$(az ad app show --id "$CLIENT_ID" --query "displayName" -o tsv 2>/dev/null || echo "")
  if [[ -n "$APP_CHECK" ]]; then
    log "App Registration: $APP_CHECK ($CLIENT_ID)"
  else
    err "App Registration not found"
    errors=$((errors + 1))
  fi

  # Verify federated credentials
  local OBJECT_ID
  OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
  local FC_COUNT
  FC_COUNT=$(az ad app federated-credential list --id "$OBJECT_ID" --query "length(@)" -o tsv 2>/dev/null || echo "0")

  if [[ "$MULTI_ENV" == true ]]; then
    # Expected: 2 common (main, pr) + N deploy envs + 1 destroy = N + 3
    local EXPECTED_FC=$(( ${#ENVIRONMENTS[@]} + 3 ))
  else
    local EXPECTED_FC=4
  fi

  if [[ "$FC_COUNT" -ge "$EXPECTED_FC" ]]; then
    log "Federated credentials: $FC_COUNT configured (expected $EXPECTED_FC)"
  else
    warn "Federated credentials: $FC_COUNT found (expected $EXPECTED_FC)"
  fi

  # Verify RBAC
  local SP_OBJECT_ID
  SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)
  local ROLE_COUNT
  ROLE_COUNT=$(az role assignment list --assignee "$SP_OBJECT_ID" --query "length(@)" -o tsv 2>/dev/null || echo "0")
  if [[ "$ROLE_COUNT" -gt 0 ]]; then
    log "RBAC assignments: $ROLE_COUNT role(s)"
  else
    err "No RBAC assignments found"
    errors=$((errors + 1))
  fi

  # Verify GitHub secrets
  if [[ "$MULTI_ENV" == true ]]; then
    # Check repo-level shared secrets
    for SECRET in AZURE_CLIENT_ID AZURE_TENANT_ID; do
      if gh secret list -R "$REPO_FULL" | grep -q "$SECRET"; then
        log "Repo secret: $SECRET ✓"
      else
        err "Repo secret: $SECRET not found"
        errors=$((errors + 1))
      fi
    done

    # Check environment-level secrets
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME _ENV_SUB _ENV_ROLE <<< "$ENV_ENTRY"
      local GH_ENV_NAME="azure-deploy-${ENV_NAME}"
      local ENV_SECRETS_OK=true

      for SECRET in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
        if gh secret list -R "$REPO_FULL" --env "$GH_ENV_NAME" 2>/dev/null | grep -q "$SECRET"; then
          : # ok
        else
          ENV_SECRETS_OK=false
        fi
      done

      if [[ "$ENV_SECRETS_OK" == true ]]; then
        log "Environment secrets: $GH_ENV_NAME ✓"
      else
        err "Environment secrets incomplete: $GH_ENV_NAME"
        errors=$((errors + 1))
      fi
    done
  else
    for SECRET in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
      if gh secret list -R "$REPO_FULL" | grep -q "$SECRET"; then
        log "GitHub secret: $SECRET ✓"
      else
        err "GitHub secret: $SECRET not found"
        errors=$((errors + 1))
      fi
    done
  fi

  return $errors
}

# ──────────────────────────────────────────────────────
# Print summary
# ──────────────────────────────────────────────────────
print_summary() {
  step "Onboarding Complete"

  echo -e "${GREEN}${BOLD}AutoCloud is ready for ${REPO_FULL}!${NC}\n"

  echo -e "${BOLD}What was configured:${NC}"
  echo "  1. Entra ID App Registration: $SP_NAME (Client ID: $CLIENT_ID)"

  if [[ "$MULTI_ENV" == true ]]; then
    # Federated creds
    local FC_LIST="main, PR"
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME _SUB _ROLE <<< "$ENV_ENTRY"
      FC_LIST="${FC_LIST}, azure-deploy-${ENV_NAME}"
    done
    FC_LIST="${FC_LIST}, azure-destroy"
    echo "  2. Federated credentials for OIDC ($FC_LIST)"

    # RBAC
    echo "  3. RBAC assignments:"
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME ENV_SUB ENV_ROLE <<< "$ENV_ENTRY"
      echo "     • $ENV_NAME → $ENV_ROLE on subscription $ENV_SUB"
    done

    # Secrets
    echo "  4. GitHub secrets:"
    echo "     • Repo-level: AZURE_CLIENT_ID, AZURE_TENANT_ID"
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME _SUB _ROLE <<< "$ENV_ENTRY"
      echo "     • azure-deploy-${ENV_NAME}: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
    done

    # Environments
    echo "  5. GitHub environments:"
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME _SUB _ROLE <<< "$ENV_ENTRY"
      echo "     • azure-deploy-${ENV_NAME} (branch: main)"
    done
    echo "     • azure-destroy"

    echo -e "\n${BOLD}Environment → Subscription mapping:${NC}"
    echo "  ┌─────────────────────┬──────────────────────────────────────────┐"
    printf "  │ %-19s │ %-40s │\n" "Environment" "Subscription ID"
    echo "  ├─────────────────────┼──────────────────────────────────────────┤"
    for ENV_ENTRY in "${ENVIRONMENTS[@]}"; do
      IFS='|' read -r ENV_NAME ENV_SUB _ROLE <<< "$ENV_ENTRY"
      printf "  │ %-19s │ %-40s │\n" "$ENV_NAME" "$ENV_SUB"
    done
    echo "  └─────────────────────┴──────────────────────────────────────────┘"
  else
    echo "  2. Federated credentials for OIDC (main, PR, azure-deploy, azure-destroy)"
    echo "  3. RBAC: $RBAC_ROLE on subscription $SUBSCRIPTION_ID"
    echo "  4. GitHub secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
    echo "  5. GitHub environments: azure-deploy (branch: main), azure-destroy"
  fi

  echo -e "\n${BOLD}Next steps:${NC}"
  echo "  1. Copy the AutoCloud workflows to your repo:"
  echo "       cp -r .github/workflows/ <your-repo>/.github/workflows/"
  echo "  2. Add deployment templates under .azure/deployments/"
  echo "  3. Open a PR to trigger the plan workflow"
  echo "  4. Merge or comment /deploy to deploy"
  echo ""
  echo -e "  ${CYAN}Optional:${NC}"
  echo "  • Set SLACK_WEBHOOK_URL secret for Slack notifications"

  if [[ "$MULTI_ENV" == true ]]; then
    echo "  • Configure required reviewers on azure-deploy-prod environment"
    echo "  • Update your deploy workflow to reference environment-specific secrets"
    echo "  • Use the 'environment' field in parameters.json to select the target environment"
  else
    echo "  • Configure required reviewers on azure-deploy environment"
  fi
  echo "  • Add CODEOWNERS for .azure/deployments/ directory"

  echo -e "\n${BOLD}Verify with a test:${NC}"
  echo "  gh workflow run autocloud-plan.yml -R $REPO_FULL"

  echo ""
}

# ──────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────
main() {
  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║       AutoCloud Onboarding Setup         ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${NC}"

  check_prerequisites
  gather_inputs
  create_app_registration
  configure_oidc
  assign_rbac
  configure_github
  verify_setup || true
  print_summary
}

# Allow non-interactive usage via env vars
#
# Single-environment mode:
#   GITHUB_REPO_URL=https://github.com/org/repo \
#   SP_NAME=sp-autocloud-repo \
#   SUBSCRIPTION_ID=xxx \
#   RBAC_ROLE=Contributor \
#   .github/scripts/onboard.sh
#
# Multi-environment mode:
#   GITHUB_REPO_URL=https://github.com/org/repo \
#   SP_NAME=sp-autocloud-repo \
#   AUTOCLOUD_ENVIRONMENTS="dev|sub-id-1|Contributor,staging|sub-id-2|Contributor,prod|sub-id-3|Contributor+UserAccessAdministrator" \
#   .github/scripts/onboard.sh
main "$@"
