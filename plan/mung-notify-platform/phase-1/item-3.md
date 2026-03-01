---
tier: medium-item
phase: 1
item: 3
status: done
completed-at: 2026-03-01
---

# Item 3 — Add CLI add/help support for metadata flags

## Goal
Expose metadata flags in CLI parse/routing for `mung add` and make help output explicit.

## Scope

**In scope:**
- Parse `--source`, `--session`, `--kind`
- Route metadata values into `Commands.add`
- Update command help text

**Out of scope:**
- list/count/clear metadata filters
- dedupe/replace behavior

## Files to Modify
- `Sources/MungMung/CLI/CLIParser.swift` — metadata flag parsing + add routing
- `Sources/MungMung/CLI/Commands.swift` — `add` signature/plumbing + help text
- `Tests/MungMungTests/CLIParserTests.swift` — parser coverage for new flags
- `Tests/MungMungTests/CommandsTests.swift` — add command metadata behavior

## Dependencies
- `item-1.md`
- `item-2.md`

## Exit Criteria
- `mung add` accepts metadata flags with no regressions to existing commands.
- Help text documents metadata flags clearly.

## Acceptance Criteria
- New metadata flags parse as data flags (not bool-only).
- `Commands.add` persists metadata into alert state.
- `mung help` includes metadata options and examples.
- All parser/add command tests pass.

## Completion Notes
- Added parser support for `--source`, `--session`, `--kind`.
- Routed metadata into `Commands.add` and alert creation.
- Updated `Commands.help` and tests to cover metadata options.
