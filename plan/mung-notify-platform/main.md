---
type: project
status: done
start-date: 2026-03-01
area: mung-notify-platform
tier: big
tags: [mung, notifications, agents]
---

# Mung as Agent Notification Bus (Pi/Claude first, extensible)

## Status
- [x] Phase 1: Contract v1 + Metadata Model (next-tier hint: medium)
- [x] Phase 2: Dedupe + Session Lifecycle Controls (next-tier hint: medium)
- [x] Phase 3: Action Execution Model + Reliability (next-tier hint: medium)
- [x] Phase 4: Integrations + Extensibility Kit (next-tier hint: medium)
- [x] Phase 5: Observability + Release Hardening (next-tier hint: medium)

## Goal
Make `mung` the stable local notification/action bus for AI agent workflows.
Primary users are Pi and Claude integrations (`mung-notify`), while keeping a clean, documented interface for future adapters.

## Scope

**In scope:**
- Stable CLI contract for agent notification workflows
- First-class metadata for source/session/kind, with tags as optional labels
- Update/replace semantics to avoid alert spam in long-running sessions
- Reliable click behavior and execution consistency across CLI + notification click paths
- Integration docs/examples for Pi and Claude, plus generic adapter guidance
- E2E coverage for real-world terminal/focus contexts (wezterm/ghostty + tmux/zellij)

**Out of scope:**
- Networked notification relay service
- Multi-device sync
- Replacing terminal multiplexers or terminal-native APIs
- Rich GUI product expansion beyond supporting agent-notify flows

## Architecture

### System Overview
```
┌──────────────────────┐
│ Pi / Claude adapters │
│ (mung-notify, etc.)  │
└──────────┬───────────┘
           │ mung add/list/done/clear
           ▼
┌───────────────────────────────┐
│ mung CLI + Commands + Parser  │
└──────────┬─────────────┬──────┘
           │             │
           ▼             ▼
┌────────────────┐   ┌─────────────────────────┐
│ AlertStore     │   │ UNUserNotificationCenter│
│ ~/.local/...   │   │ send/remove/click       │
└────────┬───────┘   └───────────┬─────────────┘
         │                       click
         │                        ▼
         └──────────────▶┌──────────────────────┐
                         │ Commands.done(run: ) │
                         │ + shell action       │
                         └──────────────────────┘
```

### Components
| Component | Responsibility | Tech |
|-----------|----------------|------|
| Agent adapters | Emit/update/clear alerts for sessions | TypeScript/Bash |
| CLI parser/commands | Stable command contract + behavior | Swift |
| AlertStore | Durable local state + filters | JSON files |
| NotificationManager | Native send/remove behavior | UNUserNotificationCenter |
| Action execution | Run on_click / focus scripts | Process + shell |
| Menu bar UI | Local observability + manual control | SwiftUI |

### Data Flow
Adapters call `mung add` with session-scoped metadata. Alerts are persisted, then sent through macOS notifications.
Clicks and CLI dismissal share `Commands.done(...)`, which removes state, removes native notification, optionally runs action, and triggers sketchybar refresh.

### Tech Stack
| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Core app/CLI | Swift | Native macOS notification APIs + simple distribution |
| Notification API | UNUserNotificationCenter | Reliable click handling and lifecycle control |
| State | Local JSON files | Transparent, script-friendly, easy filter semantics |
| Integrations | TypeScript/Bash | Matches Pi/Claude extension ecosystem |

### Key Decisions
| Decision | Choice | Alternatives Considered | Rationale |
|----------|--------|--------------------------|-----------|
| Contract direction | Metadata-first agent contract | Tags-only contract | Clearer adapter semantics and filtering |
| Metadata model | Add explicit metadata fields and keep tags optional | Tags-only forever | Better query ergonomics and cleaner integrations |
| Update control | Add dedupe/replace semantics | Always append alerts | Prevent noisy repeats in iterative agent turns |
| Click behavior | Single shared path via `Commands.done` | Separate click-specific path | Consistent behavior and lower maintenance |
| Extensibility strategy | Publish adapter contract + examples | Ad-hoc per integration | Faster onboarding for new tools |

## Phases

### Phase 1: Contract v1 + Metadata Model
- **Milestone:** CLI contract covers agent source/session/kind metadata with deterministic filtering semantics.
- **Description:** Extend CLI surface for agent workflows and define canonical metadata field/filter rules.
- **Depends on:** none
- **Estimated effort:** ~6h
- **Next-tier hint:** medium

### Phase 2: Dedupe + Session Lifecycle Controls
- **Milestone:** Session updates can replace/dedupe alerts cleanly and cleanup commands are session-safe.
- **Description:** Add deterministic update semantics so repetitive agent events do not spam users. Improve session-specific cleanup operations.
- **Depends on:** Phase 1
- **Estimated effort:** ~6h
- **Next-tier hint:** medium

### Phase 3: Action Execution Model + Reliability
- **Milestone:** Action execution behavior is explicit, consistent, and diagnosable across CLI and notification click contexts.
- **Description:** Keep `--on-click` behavior explicit, add structured action direction, and document/implement reliable execution context handling.
- **Depends on:** Phase 1
- **Estimated effort:** ~8h
- **Next-tier hint:** medium

### Phase 4: Integrations + Extensibility Kit
- **Milestone:** Pi and Claude reference integrations are documented and validated; third-party adapter path is clear.
- **Description:** Publish integration contract, adapter upgrade notes, and copy-paste examples for new adapters.
- **Depends on:** Phase 1, Phase 2, Phase 3
- **Estimated effort:** ~5h
- **Next-tier hint:** medium

### Phase 5: Observability + Release Hardening
- **Milestone:** Diagnostics and E2E coverage support confident release and maintenance.
- **Description:** Add logs/inspection paths and automate key contract checks before shipping.
- **Depends on:** Phase 2, Phase 3, Phase 4
- **Estimated effort:** ~7h
- **Next-tier hint:** medium

## Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| CLI surface grows too quickly | Medium | Keep v1 focused; defer non-essential flags |
| Terminal focus behavior varies by environment | High | Maintain platform behavior matrix and explicit best-effort guidance |
| Contract regressions | High | Add contract tests using current `mung-notify` flows |
| Alert dedupe logic becomes ambiguous | Medium | Define deterministic precedence and stable keys |

## Principles
- Clear, explicit CLI contract evolution first.
- Agent-session isolation is a first-class invariant.
- One behavior path per lifecycle action where possible.
- Docs/tests are shipping artifacts, not afterthoughts.

## Required Findings / Approvals
- Confirm final metadata field names and defaults.
- Confirm dedupe strategy (`dedupe-key` behavior and conflict resolution).
- Confirm structured action scope for v1 (minimal set only).

## Log
- 2026-03-01: Created big-tier architecture plan for mung as agent notification bus.
- 2026-03-01: Completed Phase 1 (metadata model, CLI flags, filters, docs, and tests).
- 2026-03-01: Completed Phase 2 (`--dedupe-key`, session-scoped replacement semantics, and coverage).
- 2026-03-01: Completed Phase 3 (action execution context reliability + diagnostics + tests).
- 2026-03-01: Completed Phase 4 (integration kit docs, platform matrix, and reference-flow validation tests).
- 2026-03-01: Completed Phase 5 (doctor diagnostics, release-hardening checks, and shipping checklist).
- 2026-03-01: Prepared release artifacts (`CHANGELOG.md`, `RELEASE_PREP.md`) and verified release command path.
