---
type: project
status: done
start-date: 2026-03-01
area: mung-notify-platform
tier: medium
phase: 4
tags: [mung, integrations, adapters]
---

# Phase 4 — Integrations + Extensibility Kit

## Status
- [x] Item 1: Publish adapter contract and lifecycle guidance
- [x] Item 2: Add Pi/Claude reference integration examples
- [x] Item 3: Publish platform behavior matrix and validate reference flows

## Goal
Provide first-class integration guidance for Pi/Claude and a clear onboarding path for additional adapters.

## Scope

**In scope:**
- Adapter contract docs (required/optional flags)
- Lifecycle mapping for update/action/session cleanup flows
- Pi/Claude reference examples
- Published platform behavior matrix (exact/practical_exact/best_effort/app_only)
- CLI-level reference flow validation tests

**Out of scope:**
- Full third-party ecosystem support in this phase
- Core action model redesign

## Item Index
1. [item-1.md](item-1.md) — Adapter contract + lifecycle guidance
2. [item-2.md](item-2.md) — Pi/Claude reference examples + upgrade notes
3. [item-3.md](item-3.md) — Platform matrix publication + reference flow tests

## Files Touched
- `README.md`
- `SPEC.md`
- `Tests/MungMungTests/CLIIntegrationTests.swift`

## Verification
- `swift test` passes with added reference-flow integration tests.

## Log
- 2026-03-01: Completed Phase 4 docs/examples and reference-flow validation.
