---
tier: medium-item
phase: 1
item: 1
status: done
completed-at: 2026-03-01
---

# Item 1 — Finalize metadata contract + filtering rules

## Goal
Define the v1 metadata contract for `source`, `session`, and `kind` for agent integrations.

## Scope

**In scope:**
- Canonical flag names and semantics
- Filtering rules across tags + metadata dimensions
- JSON output expectations for adapter consumers
- Pi/Claude-oriented usage examples

**Out of scope:**
- Implementing parser/model/store code changes
- Dedupe/replace semantics

## Files to Modify
- `SPEC.md` — add contract table and filtering rules
- `README.md` — add practical examples and migration notes

## Dependencies
- none

## Exit Criteria
- Contract is written with concrete examples for add/list/count/clear.
- Filtering rules are unambiguous (no implicit behavior).
- Adapter command shape is explicit.

## Acceptance Criteria
- Includes a table covering: `--source`, `--session`, `--kind` meanings.
- Includes filter behavior examples for `--tag` + metadata flags.
- Includes at least one Pi and one Claude usage example.
- Clearly marks this as v1 metadata contract.

## Completion Notes
- Added v1 metadata contract section to `SPEC.md` (flags and filtering rules).
- Added Pi/Claude examples aligned to metadata-first usage.
- Added roadmap-level v1 metadata contract section to `README.md`.
