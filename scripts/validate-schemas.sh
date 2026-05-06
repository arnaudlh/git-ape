#!/usr/bin/env bash
# Validates every JSON artifact under .azure/deployments/ and tests/fixtures/
# against its corresponding schema in schemas/git-ape/<artifact>/v1.json.
#
# The schema is selected by the artifact's base file name. Files inside any
# directory named _invalid are skipped — they are exercised by the negative
# tests in tests/bash/schema-validation.bats.
#
# Usage: scripts/validate-schemas.sh [--quiet]
#
# Exit codes:
#   0 — every scanned file validated against its schema
#   1 — at least one file failed validation
#   2 — usage / environment error
set -euo pipefail

# Resolve repo root from this script's location (works regardless of cwd).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEMA_ROOT="${REPO_ROOT}/schemas/git-ape"

QUIET=0
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=1
fi

if ! command -v check-jsonschema >/dev/null 2>&1; then
  echo "validate-schemas: check-jsonschema is required but not installed" >&2
  echo "  install via: brew install check-jsonschema    (macOS)" >&2
  echo "             pip install check-jsonschema      (Python)" >&2
  exit 2
fi

# Map artifact base file name → schema file.
schema_for() {
  case "$1" in
    state.json)                  echo "${SCHEMA_ROOT}/state/v1.json" ;;
    metadata.json)               echo "${SCHEMA_ROOT}/metadata/v1.json" ;;
    security-gate.json)          echo "${SCHEMA_ROOT}/security-gate/v1.json" ;;
    requirements.json)           echo "${SCHEMA_ROOT}/requirements/v1.json" ;;
    cost-estimate.json)          echo "${SCHEMA_ROOT}/cost-estimate/v1.json" ;;
    policy-recommendations.json) echo "${SCHEMA_ROOT}/policy-recommendations/v1.json" ;;
    plugin.json)                 echo "${SCHEMA_ROOT}/plugin/v1.json" ;;
    *)                           echo "" ;;
  esac
}

failures=0
scanned=0
skipped=0

# Collect candidate files. We use NUL-separated find output to handle paths
# safely. The patterns intentionally cover only artifacts produced by the
# Git-Ape pipeline; ARM templates (template.json, parameters.json) are
# validated by Azure-side tools, not by this script.
candidates=$(
  {
    if [[ -d "${REPO_ROOT}/.azure/deployments" ]]; then
      find "${REPO_ROOT}/.azure/deployments" -type f -name '*.json' -print0
    fi
    if [[ -d "${REPO_ROOT}/tests/fixtures" ]]; then
      find "${REPO_ROOT}/tests/fixtures" -type f -name '*.json' \
        -not -path '*/_invalid/*' -print0
    fi
    # plugin.json at repo root.
    if [[ -f "${REPO_ROOT}/plugin.json" ]]; then
      printf '%s\0' "${REPO_ROOT}/plugin.json"
    fi
  } | tr '\0' '\n'
)

if [[ -z "${candidates}" ]]; then
  if [[ "${QUIET}" -eq 0 ]]; then
    echo "validate-schemas: nothing to scan (no fixtures or deployments yet)"
  fi
  exit 0
fi

while IFS= read -r file; do
  [[ -z "${file}" ]] && continue
  base=$(basename "${file}")
  schema=$(schema_for "${base}")

  if [[ -z "${schema}" ]]; then
    if [[ "${QUIET}" -eq 0 ]]; then
      echo "skip  ${file#"${REPO_ROOT}"/}  (no schema registered for ${base})"
    fi
    skipped=$((skipped + 1))
    continue
  fi

  if [[ ! -f "${schema}" ]]; then
    echo "fail  ${file#"${REPO_ROOT}"/}  (schema not found: ${schema})" >&2
    failures=$((failures + 1))
    continue
  fi

  if check-jsonschema --schemafile "${schema}" "${file}" >/dev/null 2>&1; then
    scanned=$((scanned + 1))
    if [[ "${QUIET}" -eq 0 ]]; then
      echo "ok    ${file#"${REPO_ROOT}"/}  (schema: ${schema#"${REPO_ROOT}"/})"
    fi
  else
    failures=$((failures + 1))
    echo "FAIL  ${file#"${REPO_ROOT}"/}" >&2
    # Re-run to surface the actual validator output to stderr.
    check-jsonschema --schemafile "${schema}" "${file}" 2>&1 | sed 's/^/      /' >&2 || true
  fi
done <<< "${candidates}"

if [[ "${QUIET}" -eq 0 ]] || [[ "${failures}" -gt 0 ]]; then
  echo "---"
  echo "scanned: ${scanned}  skipped: ${skipped}  failures: ${failures}"
fi

if [[ "${failures}" -gt 0 ]]; then
  exit 1
fi
exit 0
