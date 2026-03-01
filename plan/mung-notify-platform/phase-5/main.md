---
type: project
status: done
start-date: 2026-03-01
area: mung-notify-platform
tier: medium
phase: 5
tags: [mung, observability, release]
---

# Phase 5 — Observability + Release Hardening

## Status
- [x] Item 1: Add runtime diagnostics and lifecycle debug hooks
- [x] Item 2: Expand automated confidence checks
- [x] Item 3: Publish release checklist and post-release verification guide

## Goal
Ship a supportable release with diagnostics and repeatable validation steps.

## Scope

**In scope:**
- `mung doctor` diagnostics surface (`text` + `--json`)
- Lifecycle debug logging controls for mutation commands
- Integration/unit tests for diagnostics and release-critical flows
- Release verification command + checklist documentation

**Out of scope:**
- Persistent analytics backend
- Remote telemetry pipeline

## Item Index
1. [item-1.md](item-1.md) — Runtime diagnostics + lifecycle logging
2. [item-2.md](item-2.md) — Automated confidence checks expansion
3. [item-3.md](item-3.md) — Release checklist + post-release verification

## Artifacts
- `plan/mung-notify-platform/phase-5/release-checklist.md`
- `CHANGELOG.md`
- `RELEASE_PREP.md`

## Files Touched
- `Sources/MungMung/CLI/CLIParser.swift`
- `Sources/MungMung/CLI/Commands.swift`
- `Sources/MungMung/Services/NotificationManager.swift`
- `Tests/MungMungTests/CLIParserTests.swift`
- `Tests/MungMungTests/CommandsTests.swift`
- `Tests/MungMungTests/CLIIntegrationTests.swift`
- `Tests/MungMungTests/NotificationManagerTests.swift`
- `README.md`
- `SPEC.md`
- `CHANGELOG.md`
- `RELEASE_PREP.md`
- `Makefile`

## Verification
- `swift test` passes with diagnostics + reference-flow coverage.
- `make verify-release` provides a repeatable release-hardening check path.

## Log
- 2026-03-01: Completed diagnostics surface, test expansion, and release checklist.
- 2026-03-01: Added final release prep artifacts (`CHANGELOG.md`, `RELEASE_PREP.md`) with commit grouping and command sequence.
