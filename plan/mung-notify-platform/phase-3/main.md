---
type: project
status: done
start-date: 2026-03-01
area: mung-notify-platform
tier: medium
phase: 3
tags: [mung, actions, reliability]
---

# Phase 3 — Action Execution Model + Reliability

## Status
- [x] Item 1: Define on_click execution context contract
- [x] Item 2: Implement shell/cwd resolution and debug diagnostics
- [x] Item 3: Add tests and docs for reliability behavior

## Goal
Make action execution behavior explicit, reliable, and diagnosable across CLI and notification-click paths.

## Scope

**In scope:**
- Explicit shell context resolution for on_click execution
- Optional working-directory control for actions
- Debug diagnostics for action/sketchybar failures
- Documentation and tests for execution behavior

**Out of scope:**
- Structured multi-action payload formats
- Remote action execution

## Files Touched
- `Sources/MungMung/Services/ShellHelper.swift`
- `Tests/MungMungTests/ShellHelperTests.swift`
- `README.md`
- `SPEC.md`

## Verification
- `swift test` passes with shell context and debug-flag coverage.

## Log
- 2026-03-01: Completed Phase 3 implementation (execution context resolution + diagnostics).
