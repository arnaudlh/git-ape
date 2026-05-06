# tests/

Static-validation tests for Git-Ape. These tests do not require an Azure subscription — they exercise the JSON schemas, fixtures, and emitted artifact shapes.

## Layout

```
tests/
├── README.md                           ← you are here
├── fixtures/                           ← canonical valid + invalid JSON samples
├── bash/                               ← bats-core tests
│   └── schema-validation.bats          ← positive + negative schema assertions
└── parity/                             ← (placeholder) future bash↔PowerShell emitter parity tests
    └── .gitkeep
```

## Running locally

Prerequisites: `bash`, `bats-core`, `check-jsonschema` (and `jq` for parity tests once they land).

On macOS:

```bash
brew install bats-core check-jsonschema jq
```

On Ubuntu / GitHub Actions runners:

```bash
sudo apt-get install -y bats jq
pipx install check-jsonschema      # or: pip install --user check-jsonschema
```

Run the full suite from the repo root:

```bash
scripts/validate-schemas.sh        # bulk validation of every committed fixture
bats tests/bash                    # explicit positive + negative assertions
```

## What is intentionally NOT here

- ARM-TTK / Checkov / PSRule for Azure / MSDO templateanalyzer — covered by template-side tooling, not these tests.
- Real-Azure E2E sandbox tests — gated by an `/e2e` label in a follow-up workflow.
- Agent behavioral snapshot tests — captured in a follow-up issue.
