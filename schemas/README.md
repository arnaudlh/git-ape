# Git-Ape JSON Schemas

This directory holds the authoritative JSON Schemas (draft 2020-12) for every
JSON artifact Git-Ape emits. Schemas are versioned per artifact and validated
in CI on every PR.

## Layout

```
schemas/
├── README.md                              ← you are here
└── git-ape/
    ├── _defs/
    │   └── v1.json                        ← canonical shared types
    ├── state/v1.json                      ← state.json artifact
    ├── metadata/v1.json                   ← metadata.json artifact
    ├── requirements/v1.json               ← requirements.json artifact
    ├── security-gate/v1.json              ← security-gate.json artifact
    ├── cost-estimate/v1.json              ← cost-estimate.json artifact
    ├── policy-recommendations/v1.json     ← policy-recommendations.json artifact
    └── plugin/v1.json                     ← plugin.json (this repo's manifest)
```

## Versioning policy

- **Per-artifact `schemaVersion`.** Every artifact carries its own
  `schemaVersion` field. The shared `$defs` in `_defs/v1.json` are versioned
  together as a release train: a new `_defs/v2.json` lands when at least one
  artifact graduates to v2.
- **Major bumps for breaking changes.** Renaming, removing, or retyping a
  documented field. Migrate the in-tree corpus and emitter scripts in the same
  PR.
- **Minor bumps for additive changes.** Adding a new optional field, relaxing a
  pattern, broadening an enum. Old documents stay valid against the new schema.
- **Patch bumps are not used.** JSON Schema documents do not need patch
  semantics — descriptive changes go in via PR without a version bump.

## Strictness rules

- `additionalProperties: false` on every top-level artifact object.
- Nested objects (e.g. `managedResources[]` items) allow extras during the
  transition — they will tighten in a future minor.
- `$schema` is whitelisted as a known top-level extension key on every
  artifact so editors can attach a schema without failing validation.
- Required fields are explicit. Anything not in `required` is optional and
  must be omitted rather than set to `null` unless the schema documents
  `null` as a valid type.

## How emitters reference schemas

When an emitter (e.g. a future `deploy-stack.sh`) writes an artifact, it
SHOULD set a relative `$schema` field pointing at the schema for that
artifact:

```json
{
  "$schema": "../../../schemas/git-ape/state/v1.json",
  "schemaVersion": "1.0",
  "deploymentId": "deploy-20260506-001"
}
```

The relative path is resolved against the artifact's location. Editors with
JSON Schema support will auto-validate the file with no configuration. CI
ignores this field — `scripts/validate-schemas.sh` selects the schema based
on the file name.

## How CI uses these schemas

`.github/workflows/git-ape-ci.yml` invokes `scripts/validate-schemas.sh` on
every PR. The script:

1. Walks `.azure/deployments/**/*.json` and `tests/fixtures/**/*.json`.
2. Selects the schema for each file by its base name (`state.json`,
   `metadata.json`, …).
3. Runs `check-jsonschema --schemafile <schema> <file>`.
4. Fails the job if any file violates its schema.

Negative-test fixtures live under `tests/fixtures/_invalid/` and are
deliberately rejected by the corresponding bats test, not the bulk
validator.

## Adding or evolving a schema

1. Decide major vs minor (see "Versioning policy").
2. Author or copy the schema file.
3. Update `tests/fixtures/<artifact>/` with a valid sample and (when adding
   a new constraint) a negative sample under `tests/fixtures/_invalid/`.
4. Run `scripts/validate-schemas.sh` locally.
5. Update `tests/bash/schema-validation.bats` if you added a new artifact.
6. If you are introducing a breaking change, also add a migration step in a
   follow-up PR and a one-line note in the artifact's `description`.

## Known follow-ups

- **Deduplicate `$defs` via cross-file `$ref`.** Today every per-artifact
  schema embeds its own copy of the shared types from `_defs/v1.json`. This
  keeps `check-jsonschema` invocations trivially portable. A follow-up will
  switch to bundled `$ref`s using a single registry document. Tracked
  alongside the doc-generation work.
- **`requirements.json` `resources[].configuration` discrimination.** The
  v1.0 schema accepts any object; a v1.1 will use `oneOf` keyed on `type` so
  per-resource shapes are validated.
- **SchemaStore.org submission.** Once the registry stabilises, submit a PR
  to `SchemaStore/schemastore` so editors discover Git-Ape artifacts by file
  pattern with no workspace setup.
