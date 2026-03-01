---
tier: medium-item
phase: 1
item: 4
status: done
completed-at: 2026-03-01
---

# Item 4 — Add list/count/clear metadata filters

## Goal
Allow alert query and cleanup commands to filter by metadata (`source`, `session`, `kind`) in addition to existing tag filters.

## Scope

**In scope:**
- Parse metadata filter flags on `list`, `count`, `clear`
- Extend command/store filter pipeline for metadata matching
- Define behavior when combining tag filters with metadata filters

**Out of scope:**
- Dedupe or replace/update semantics
- UI-specific filtering features

## Files to Modify
- `Sources/MungMung/CLI/CLIParser.swift` — metadata filters for list/count/clear
- `Sources/MungMung/CLI/Commands.swift` — command-level filter wiring
- `Sources/MungMung/Services/AlertStore.swift` — metadata-aware list/count/clear filtering
- `Tests/MungMungTests/CommandsTests.swift` — command filter behavior tests
- `Tests/MungMungTests/CLIIntegrationTests.swift` — subprocess filter contract tests

## Dependencies
- `item-1.md`
- `item-2.md`
- `item-3.md`

## Exit Criteria
- list/count/clear support metadata filters with deterministic logic.
- Combined tag+metadata filters behave per documented contract.
- No regression to current tag-only behavior.

## Acceptance Criteria
- `mung list --json --session <id>` returns only matching alerts.
- `mung count --source <src>` matches command-level expectations.
- `mung clear --kind <kind>` removes only matching alerts.
- Existing tag-based filter tests still pass unchanged.

## Completion Notes
- Added metadata filter routing for `list`, `count`, and `clear` in `CLIParser`.
- Added metadata-aware filter parameters to `Commands` and `AlertStore`.
- Implemented OR-within-dimension and AND-across-dimensions behavior in store filtering.
- Added unit/integration tests for metadata filter behavior.
