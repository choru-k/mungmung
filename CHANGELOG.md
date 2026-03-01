# Changelog

All notable changes to `mungmung` are documented in this file.

## [0.7.0] - 2026-03-01

### Added
- First-class agent metadata contract for alerts:
  - `source`, `session`, `kind` fields
  - CLI flags: `--source`, `--session`, `--kind`
  - Metadata-aware filters for `list`, `count`, and `clear`
- Dedupe lane support:
  - `dedupe_key` field
  - CLI flag: `--dedupe-key`
  - Deterministic replacement semantics on `add`
- Runtime diagnostics command:
  - `mung doctor`
  - `mung doctor --json`
- Action execution context controls:
  - `MUNG_ON_CLICK_SHELL`
  - `MUNG_ON_CLICK_CWD`
  - `MUNG_DEBUG_ACTIONS`
- Lifecycle diagnostics control:
  - `MUNG_DEBUG_LIFECYCLE`
- Release verification target:
  - `make verify-release`

### Changed
- Notification click handling now uses the same dismissal path as CLI:
  - `Commands.done(id: ..., run: ...)`
- Menu bar Settings flow is now sequential:
  - close menu first, then open Settings
- `on_click` shell resolution is explicit and deterministic:
  1. `MUNG_ON_CLICK_SHELL`
  2. `SHELL`
  3. `/bin/sh`
- `NotificationManager` runtime detection was hardened with explicit notification-availability checks.
- Product/docs direction is metadata-first for Pi/Claude adapters; tags remain optional labels.

### Fixed
- Resolved Sendable closure-capture warning path in notification permission request handling.
- Improved failure visibility for action/sketchybar launch failures when debug flags are enabled.

### Documentation
- Expanded integration/extensibility docs for Pi/Claude adapters.
- Published adapter lifecycle mapping and focus behavior matrix.
- Added observability/release-hardening guidance and checklist.

### Tests
- Expanded command/parser/integration coverage for metadata, dedupe, action runtime, and diagnostics.
- Added new shell helper and notification runtime tests.
- Full suite currently passes: **204 / 204** tests.
