---
tier: medium-item
phase: 1
item: 2
status: done
completed-at: 2026-03-01
---

# Item 2 — Extend alert model/persistence for source/session/kind

## Goal
Add first-class metadata fields to persisted alert objects.

## Scope

**In scope:**
- Add optional metadata fields to `Alert` model
- Update Codable encode/decode behavior for new keys
- Verify round-trip and key mapping behavior for metadata payloads

**Out of scope:**
- CLI flag parsing/routing
- Metadata filtering logic in commands/store

## Files to Modify
- `Sources/MungMung/Models/Alert.swift` — add metadata fields + coding keys
- `Tests/MungMungTests/AlertTests.swift` — round-trip and key mapping coverage

## Dependencies
- `item-1.md`

## Exit Criteria
- Alerts with and without metadata round-trip correctly.
- Encoded JSON includes metadata keys when provided.
- Metadata-free payloads decode cleanly.

## Acceptance Criteria
- `Alert` supports optional `source`, `session`, `kind` fields.
- JSON output includes metadata keys only when present.
- New tests validate metadata encode/decode behavior.

## Completion Notes
- Added `source`, `session`, and `kind` fields to `Alert` model.
- Updated Codable encode/decode and initializer plumbing for metadata fields.
- Extended `AlertTests` with metadata round-trip and optionality coverage.
