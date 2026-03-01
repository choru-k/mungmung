---
type: project
status: done
start-date: 2026-03-01
area: mung-notify-platform
tier: medium
phase: 2
tags: [mung, dedupe, session]
---

# Phase 2 — Dedupe + Session Lifecycle Controls

## Status
- [x] Item 1: Add dedupe key to contract, model, and CLI surface
- [x] Item 2: Implement deterministic replacement semantics in add flow
- [x] Item 3: Validate session isolation and filtering behavior via tests

## Goal
Prevent alert spam in active agent sessions and make cleanup/session isolation operations deterministic.

## Scope

**In scope:**
- `--dedupe-key` support for add/list/count/clear
- Dedupe metadata persistence (`dedupe_key`)
- Deterministic add-time replacement behavior
- Session-aware replacement scope
- Contract + integration test coverage for dedupe/session behavior

**Out of scope:**
- Structured action redesign
- UI feature expansion

## Item Index
1. [item-1.md](item-1.md) — Add dedupe key to contract/model/CLI
2. [item-2.md](item-2.md) — Implement replacement behavior in `Commands.add`
3. [item-3.md](item-3.md) — Add session isolation and dedupe test coverage

## Files Touched
- `Sources/MungMung/Models/Alert.swift`
- `Sources/MungMung/Services/AlertStore.swift`
- `Sources/MungMung/CLI/CLIParser.swift`
- `Sources/MungMung/CLI/Commands.swift`
- `Tests/MungMungTests/AlertTests.swift`
- `Tests/MungMungTests/AlertStoreTests.swift`
- `Tests/MungMungTests/CLIParserTests.swift`
- `Tests/MungMungTests/CommandsTests.swift`
- `Tests/MungMungTests/CLIIntegrationTests.swift`
- `README.md`
- `SPEC.md`

## Verification
- `swift test` passes with dedupe + session isolation coverage.

## Log
- 2026-03-01: Completed Phase 2 implementation (`--dedupe-key`, replacement semantics, and tests).
