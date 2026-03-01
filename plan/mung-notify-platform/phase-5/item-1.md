---
tier: medium-item
phase: 5
item: 1
status: done
completed-at: 2026-03-01
---

# Item 1 — Add runtime diagnostics and lifecycle debug hooks

## Goal
Make failures diagnosable without source modifications.

## Completion Notes
- Added `mung doctor` (`text` + `--json`) for runtime context inspection.
- Added lifecycle debug logging via `$MUNG_DEBUG_LIFECYCLE`.
- Expanded help/docs for diagnostics environment controls.
