---
tier: big-phase
phase: 1
status: done
expanded-at: 2026-03-01
completed-at: 2026-03-01
---

# Phase 1 — Contract v1 + Metadata Model

## Phase Goal
Define and ship a clear v1 metadata contract for agent notifications.

## Scope

**In scope:**
- Specify canonical metadata fields for `source`, `session`, `kind`
- CLI/parser/model updates for metadata
- Metadata-aware behavior for add/list/count/clear
- Command-level tests for parse + persistence + listing/filtering

**Out of scope:**
- Aggressive command redesign
- Dedupe/replace behavior details (Phase 2)
- Advanced action modeling (Phase 3)

## Dependencies
- None

## Expansion
- Phase plan: [phase-1/main.md](phase-1/main.md)
- Item count: 5
- Expansion status: completed

## Exit Criteria
- Metadata contract is documented and implemented.
- Agent integration flows are covered by tests.
- add/list/count/clear behavior is deterministic with metadata filters.

## Next Step
Run `/superplan medium phase-2` to begin dedupe and session lifecycle controls.
