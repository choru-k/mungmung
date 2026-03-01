---
tier: medium-item
phase: 1
item: 5
status: done
completed-at: 2026-03-01
---

# Item 5 — Contract + integration test coverage

## Goal
Lock confidence that the metadata contract is fully implemented and validated for agent workflows.

## Scope

**In scope:**
- Extend unit/integration tests for metadata-aware command shapes
- Validate metadata filter behavior end-to-end
- Update user-facing docs/examples to reflect final contract

**Out of scope:**
- New product features beyond Phase 1 contract
- Large refactors unrelated to contract validation

## Files to Modify
- `Tests/MungMungTests/AlertTests.swift`
- `Tests/MungMungTests/CLIParserTests.swift`
- `Tests/MungMungTests/CommandsTests.swift`
- `Tests/MungMungTests/CLIIntegrationTests.swift`
- `README.md`
- `SPEC.md`

## Dependencies
- `item-1.md`
- `item-2.md`
- `item-3.md`
- `item-4.md`

## Exit Criteria
- Metadata integration behavior passes test suite.
- Metadata paths are tested at parser, command, and subprocess levels.
- Docs are synchronized with implemented behavior.

## Acceptance Criteria
- `swift test` passes end-to-end.
- Tests assert metadata add/list/count/clear workflows.
- README and SPEC examples are executable and consistent.
- Phase-1 deliverable can be handed to adapter authors without ambiguity.

## Completion Notes
- Extended `AlertTests`, `CLIParserTests`, `CommandsTests`, and `CLIIntegrationTests` for metadata flows.
- Updated README usage and roadmap contract sections for metadata-first commands.
- Kept SPEC and tests aligned with implemented metadata behavior.
- Verified full suite with `swift test`.
