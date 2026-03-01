---
tier: big-phase
phase: 4
status: done
expanded-at: 2026-03-01
completed-at: 2026-03-01
---

# Phase 4 — Integrations + Extensibility Kit

## Phase Goal
Provide first-class integration guidance for Pi/Claude and a clean onboarding path for other adapters.

## Scope

**In scope:**
- Pi and Claude reference integration docs/examples
- Adapter contract docs (required/optional flags, lifecycle expectations)
- Adapter upgrade notes for existing extension maintainers
- Platform behavior matrix publication (exact/best-effort constraints)

**Out of scope:**
- Supporting every third-party ecosystem in this phase
- Non-agent product marketing or website work

## Dependencies
- Phase 1, Phase 2, Phase 3

## Expansion
- Phase plan: [phase-4/main.md](phase-4/main.md)
- Item count: 3
- Expansion status: completed

## Exit Criteria
- New adapter author can implement integration using docs alone.
- Pi/Claude reference paths are validated end-to-end.
- Known platform limitations are explicit (not implicit).

## Next Step
Run `/superplan medium phase-5` to complete release hardening and observability.
