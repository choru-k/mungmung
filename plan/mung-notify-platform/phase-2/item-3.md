---
tier: medium-item
phase: 2
item: 3
status: done
completed-at: 2026-03-01
---

# Item 3 — Add session isolation and dedupe test coverage

## Goal
Prove dedupe and session lifecycle behavior with deterministic tests.

## Completion Notes
- Added unit coverage for dedupe filtering in store/commands/parser tests.
- Added integration coverage for:
  - replacement within a session
  - isolation across sessions with same dedupe key
  - list/count/clear filters using `--dedupe-key`
- Verified with full `swift test`.
