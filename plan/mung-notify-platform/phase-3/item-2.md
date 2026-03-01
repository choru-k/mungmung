---
tier: medium-item
phase: 3
item: 2
status: done
completed-at: 2026-03-01
---

# Item 2 — Implement shell/cwd resolution and debug diagnostics

## Goal
Improve action execution reliability and troubleshooting.

## Completion Notes
- Added `ShellHelper.resolveActionExecutionContext(...)`.
- Added support for `$MUNG_ON_CLICK_CWD` working directory.
- Added `$MUNG_DEBUG_ACTIONS` diagnostics for action/sketchybar launch failures.
- Kept action execution fire-and-forget behavior.
