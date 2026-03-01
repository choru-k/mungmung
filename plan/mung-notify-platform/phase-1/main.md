---
type: project
status: done
start-date: 2026-03-01
area: mung-notify-platform
tier: medium
phase: 1
tags: [mung, contract, metadata]
---

# Phase 1 — Contract v1 + Metadata Model

## Status
- [x] Item 1: Finalize metadata contract + filtering rules
- [x] Item 2: Extend alert model/persistence for source/session/kind
- [x] Item 3: Add CLI add/help support for metadata flags
- [x] Item 4: Add list/count/clear metadata filters
- [x] Item 5: Contract + integration test coverage

## Goal
Define and implement `mung` v1 metadata contract for agent notifications with first-class fields (`source`, `session`, `kind`) and deterministic filtering.

## Scope

**In scope:**
- Metadata fields and flag names for source/session/kind
- Parser/command/model/store updates required to support metadata
- Deterministic filtering behavior across metadata + tags
- Test coverage for contract behavior and integration flows

**Out of scope:**
- Dedupe/replace behavior (`dedupe-key`) 
- Structured action types beyond `--on-click`
- Large UI redesign work

## Approach
Codify explicit contract rules first (inputs, filtering semantics, output shape). Implement metadata storage in `Alert`, then expose CLI flags in `add` and filtering flags in read/cleanup commands. Treat tags as optional custom labels and validate behavior with unit + integration tests.

## Item Index
1. [item-1.md](item-1.md) — Finalize metadata contract + filtering rules
2. [item-2.md](item-2.md) — Extend alert model/persistence for source/session/kind
3. [item-3.md](item-3.md) — Add CLI add/help support for metadata flags
4. [item-4.md](item-4.md) — Add list/count/clear metadata filters
5. [item-5.md](item-5.md) — Contract + integration test coverage

## Files Likely Touched
- `Sources/MungMung/Models/Alert.swift`
- `Sources/MungMung/Services/AlertStore.swift`
- `Sources/MungMung/CLI/CLIParser.swift`
- `Sources/MungMung/CLI/Commands.swift`
- `README.md`
- `SPEC.md`
- `Tests/MungMungTests/AlertTests.swift`
- `Tests/MungMungTests/CLIParserTests.swift`
- `Tests/MungMungTests/CommandsTests.swift`
- `Tests/MungMungTests/CLIIntegrationTests.swift`

## Verification Checkpoints
1. `swift test --filter AlertTests` passes with metadata encode/decode cases.
2. `swift test --filter CLIParserTests` passes with metadata flag parsing/routing.
3. `swift test --filter CommandsTests` passes for add/list/count/clear metadata behavior.
4. `swift test --filter CLIIntegrationTests` passes for subprocess-level contract behavior.
5. Full `swift test` passes with no regressions.

## Required Findings
- Metadata+tag interaction policy for filters
- Filter precedence policy when multiple metadata filters are provided
- JSON output contract for adapter consumers

## Approval Checklist
- [x] Contract table reviewed (flag names and semantics)
- [x] Contract tests cover agent integration flows
- [x] README/SPEC examples updated for metadata-first usage

## Log
- 2026-03-01: Expanded Phase 1 into executable items.
- 2026-03-01: Completed Item 1 (metadata contract + filtering rules in README/SPEC).
- 2026-03-01: Completed Items 2-5 (model, parser/commands, metadata filters, and full test coverage).
