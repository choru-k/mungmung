---
tier: medium-item
phase: 2
item: 2
status: done
completed-at: 2026-03-01
---

# Item 2 — Implement replacement behavior in Commands.add

## Goal
Ensure repeated session updates can replace old alerts predictably.

## Completion Notes
- Implemented add-time replacement using `--dedupe-key`.
- Replacement scope:
  - session-scoped when `--session` is provided
  - global dedupe key scope when session is absent
- Removed previous matching state + notifications before inserting new alert.
