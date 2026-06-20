#!/usr/bin/env bats
#
# Schema validation tests for Git-Ape JSON artifacts.
#
# These tests assert two things:
#   1. Every fixture under tests/fixtures/<scenario>/ validates against its
#      schema (matches the bulk validator behaviour).
#   2. Every fixture under tests/fixtures/_invalid/ is REJECTED by its
#      schema. This is the contract for the count-form security gate
#      migration and the required-field tightening on state.json.
#
# Run with:  bats tests/bash

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    SCHEMAS="${REPO_ROOT}/schemas/git-ape"
    FIXTURES="${REPO_ROOT}/tests/fixtures"
}

# ----------------------------------------------------------------------------
# Tooling preflight
# ----------------------------------------------------------------------------

@test "check-jsonschema is on PATH" {
    run command -v check-jsonschema
    [ "$status" -eq 0 ]
}

@test "every schema file is itself a valid JSON Schema (draft 2020-12)" {
    for schema in "${SCHEMAS}"/_defs/v1.json \
                  "${SCHEMAS}"/state/v1.json \
                  "${SCHEMAS}"/metadata/v1.json \
                  "${SCHEMAS}"/security-gate/v1.json \
                  "${SCHEMAS}"/requirements/v1.json \
                  "${SCHEMAS}"/cost-estimate/v1.json \
                  "${SCHEMAS}"/policy-recommendations/v1.json \
                  "${SCHEMAS}"/plugin/v1.json; do
        run check-jsonschema --check-metaschema "${schema}"
        [ "$status" -eq 0 ]
    done
}

# ----------------------------------------------------------------------------
# plugin.json (the manifest at repo root)
# ----------------------------------------------------------------------------

@test "plugin.json validates against schemas/git-ape/plugin/v1.json" {
    run check-jsonschema --schemafile "${SCHEMAS}/plugin/v1.json" \
        "${REPO_ROOT}/plugin.json"
    [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------------
# Bulk validator wrapper exits clean on the committed corpus
# ----------------------------------------------------------------------------

@test "scripts/validate-schemas.sh passes on the committed fixtures" {
    run bash "${REPO_ROOT}/scripts/validate-schemas.sh" --quiet
    [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------------
# Positive fixtures (one @test per artifact type for clear failure messages)
# ----------------------------------------------------------------------------

@test "fixture: state-stack-success/state.json is valid" {
    run check-jsonschema --schemafile "${SCHEMAS}/state/v1.json" \
        "${FIXTURES}/state-stack-success/state.json"
    [ "$status" -eq 0 ]
}

@test "fixture: state-stack-failed/state.json is valid" {
    run check-jsonschema --schemafile "${SCHEMAS}/state/v1.json" \
        "${FIXTURES}/state-stack-failed/state.json"
    [ "$status" -eq 0 ]
}

@test "fixture: metadata-success/metadata.json is valid" {
    run check-jsonschema --schemafile "${SCHEMAS}/metadata/v1.json" \
        "${FIXTURES}/metadata-success/metadata.json"
    [ "$status" -eq 0 ]
}

@test "fixture: security-gate-passed/security-gate.json (count form) is valid" {
    run check-jsonschema --schemafile "${SCHEMAS}/security-gate/v1.json" \
        "${FIXTURES}/security-gate-passed/security-gate.json"
    [ "$status" -eq 0 ]
}

@test "fixture: requirements-basic/requirements.json is valid" {
    run check-jsonschema --schemafile "${SCHEMAS}/requirements/v1.json" \
        "${FIXTURES}/requirements-basic/requirements.json"
    [ "$status" -eq 0 ]
}

@test "fixture: cost-estimate-basic/cost-estimate.json is valid" {
    run check-jsonschema --schemafile "${SCHEMAS}/cost-estimate/v1.json" \
        "${FIXTURES}/cost-estimate-basic/cost-estimate.json"
    [ "$status" -eq 0 ]
}

@test "fixture: policy-recommendations-basic/policy-recommendations.json is valid" {
    run check-jsonschema --schemafile "${SCHEMAS}/policy-recommendations/v1.json" \
        "${FIXTURES}/policy-recommendations-basic/policy-recommendations.json"
    [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------------
# Negative fixtures (MUST be rejected — these are the migration contract)
# ----------------------------------------------------------------------------

@test "negative: state.json missing required fields is REJECTED" {
    run check-jsonschema --schemafile "${SCHEMAS}/state/v1.json" \
        "${FIXTURES}/_invalid/state-missing-required.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"managedResources"* ]] || [[ "$output" == *"required"* ]]
}

@test "negative: security-gate.json boolean form is REJECTED at v1.0" {
    run check-jsonschema --schemafile "${SCHEMAS}/security-gate/v1.json" \
        "${FIXTURES}/_invalid/security-gate-boolean-form.json"
    [ "$status" -ne 0 ]
    # Must specifically reject because criticalPassed is True (boolean) instead
    # of an integer count.
    [[ "$output" == *"criticalPassed"* ]] || [[ "$output" == *"integer"* ]]
}
