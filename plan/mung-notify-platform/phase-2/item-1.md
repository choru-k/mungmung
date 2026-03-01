---
tier: medium-item
phase: 2
item: 1
status: done
completed-at: 2026-03-01
---

# Item 1 — Add dedupe key to contract/model/CLI

## Goal
Introduce `--dedupe-key` as a first-class contract field and persist it as `dedupe_key` in alert state.

## Completion Notes
- Added `dedupeKey` (`dedupe_key`) to `Alert` model.
- Added CLI parser/routing support for `--dedupe-key`.
- Added command help/docs coverage in README/SPEC.
