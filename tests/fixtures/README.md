# Git-Ape test fixtures

This directory contains JSON artifact samples used by:

- `scripts/validate-schemas.sh` — bulk validation of every committed valid sample against its schema.
- `tests/bash/schema-validation.bats` — explicit positive AND negative assertions, including for the files under `_invalid/` that the bulk validator deliberately skips.

## Layout

```
tests/fixtures/
├── README.md                           ← you are here
├── state-stack-success/                ← valid state.json (deployMethod=stack, status=succeeded)
│   └── state.json
├── state-stack-failed/                 ← valid state.json (status=failed)
│   └── state.json
├── metadata-success/                   ← valid metadata.json
│   └── metadata.json
├── security-gate-passed/               ← valid security-gate.json (count form)
│   └── security-gate.json
├── requirements-basic/                 ← valid requirements.json
│   └── requirements.json
├── cost-estimate-basic/                ← valid cost-estimate.json
│   └── cost-estimate.json
├── policy-recommendations-basic/       ← valid policy-recommendations.json
│   └── policy-recommendations.json
└── _invalid/                           ← deliberately broken samples (skipped by bulk validator)
    ├── state-missing-required.json
    └── security-gate-boolean-form.json
```

## Conventions

- One artifact per folder. The folder name describes the scenario; the file name MUST be the canonical artifact name (`state.json`, `metadata.json`, …) so the bulk validator can pick the right schema.
- Folders prefixed with an underscore are excluded from the bulk validator. Use `_invalid/` for negative cases.
- Negative samples MUST also be referenced in `tests/bash/schema-validation.bats` so the failure mode is asserted, not just claimed.
- Real ARM resource IDs may be used as long as they refer to non-existent or sample subscriptions. Do **not** include real secrets, real subscription IDs from production, or anything that could be a data leak.

## Adding a new fixture

1. Pick a descriptive folder name: `<artifact>-<scenario>` (e.g. `state-multi-rg`, `policy-recommendations-empty`).
2. Drop the artifact into the folder under its canonical name.
3. Run `scripts/validate-schemas.sh` locally — it should pass.
4. If the fixture exercises a new constraint, add a matching negative sample under `_invalid/` and assert the failure in `schema-validation.bats`.
5. Mention the new fixture in your PR description.

## Adding a new artifact type

1. Author the schema under `schemas/git-ape/<artifact>/v1.json`.
2. Register the artifact's base file name in `scripts/validate-schemas.sh` (`schema_for` function).
3. Add at least one valid fixture and one negative fixture here.
4. Add explicit `@test` cases in `tests/bash/schema-validation.bats`.
5. Update `schemas/README.md`.
