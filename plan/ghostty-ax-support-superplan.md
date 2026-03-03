---
type: project
status: in-progress
start-date: 2026-03-02
area: ghostty-ax-support
tier: big+medium+small
tags: [mung, mung-notify, ghostty, accessibility]
---

# Full Superplan — Ghostty AX Support (mung + mung-notify)

## Goal
Add Ghostty tab/pane activation support using macOS Accessibility APIs, with a shared Swift helper binary used by `mung-notify` focus flow.

## Scope

**In scope**
- Swift helper binary for Ghostty AX targeting (`--target` + env fallback)
- Retry-once-then-fail behavior with actionable error messages
- `mung-notify` integration via shared focus script
- Selector-based tiering update (`ghostty + selector` => `exact`)
- Cross-platform stub behavior (non-macOS returns explicit unsupported)
- Docs/spec updates

**Out of scope**
- Non-macOS Ghostty backend implementation
- Terminal-independent generic AX automation framework
- UI changes in mung menu bar app

## Architecture

```text
Pi extension (extension.ts)
  -> builds on_click command
  -> mung-focus.sh
      -> (ghostty + selector) mung-ghostty-focus --target <selector>
           -> AppKit + ApplicationServices (AX tree)
           -> AXPress / AXSelected + app activate
      -> wezterm/tmux/zellij focus steps
```

## Big Tier Plan (Phases)

- [x] **Phase 1**: Ship shared Ghostty AX helper in `mungmung`
- [x] **Phase 2**: Integrate selector-aware focus flow in `mung-notify`
- [x] **Phase 3**: Align docs/spec/tests with new Ghostty behavior

---

## Medium Tier Expansion

### Phase 1 — Shared helper in `mungmung`

**Items**
1. [x] Add executable target + helper source
2. [x] Add packaging/distribution wiring (app bundle + cask binary)
3. [x] Add helper contract docs (README/SPEC)

**Files**
- `Package.swift`
- `Sources/MungGhosttyFocus/main.swift`
- `Scripts/create_app_bundle.sh`
- `Casks/mungmung.rb`
- `README.md`
- `SPEC.md`

### Phase 2 — `mung-notify` integration

**Items**
1. [x] Add Ghostty selector plumbing in extension command builder
2. [x] Add Ghostty AX backend dispatch in focus script
3. [x] Keep mux focus behavior intact after Ghostty selection

**Files**
- `../skills-for-ai/private/pi/mung-notify/extension.ts`
- `../skills-for-ai/private/pi/mung-notify/scripts/mung-focus.sh`

### Phase 3 — docs/tests alignment

**Items**
1. [x] Update compatibility matrix docs
2. [x] Add selector coverage to E2E matrix
3. [ ] Run full private Pi extension E2E in authenticated environment

**Files**
- `../skills-for-ai/private/pi/mung-notify/README.md`
- `../skills-for-ai/private/pi/mung-notify/E2E.md`
- `../skills-for-ai/private/pi/mung-notify/tests/e2e/mung-notify.e2e.test.ts`

---

## Small Tier Task Breakdown (Executable)

### Item 1.1 — Helper binary implementation

- [x] Task 1: Parse CLI args/env (`--target`, `--match`, bundle/retry controls)
- [x] Task 2: Traverse Ghostty AX tree and match selector text
- [x] Task 3: Perform `AXPress`/`AXSelected` with one retry and hard failure

Verification:
- `swift build`
- `.build/debug/MungGhosttyFocus --help`

### Item 1.2 — Packaging integration

- [x] Task 1: Copy helper into app bundle during distribution
- [x] Task 2: Expose helper via cask binary symlink

Verification:
- confirm `Scripts/create_app_bundle.sh` copies `MungGhosttyFocus` when present
- confirm cask declares `mung-ghostty-focus`

### Item 2.1 — Extension selector routing

- [x] Task 1: Read selector + selector mode from env
- [x] Task 2: Set Ghostty focus tier to `exact` when selector exists
- [x] Task 3: Append selector args to focus script payload

Verification:
- inspect generated `--on-click` command in E2E test harness log

### Item 2.2 — Focus script Ghostty backend

- [x] Task 1: Add helper resolution (`mung-ghostty-focus` / app bundle fallback)
- [x] Task 2: Add macOS backend function + platform stub dispatcher
- [x] Task 3: Enforce non-zero failure path for selector-driven Ghostty focus

Verification:
- `bash -n ../skills-for-ai/private/pi/mung-notify/scripts/mung-focus.sh`

### Item 3.1 — Docs/tests updates

- [x] Task 1: Update compatibility behavior docs (selector exact path)
- [x] Task 2: Update E2E matrix cases for selector and selector+tmux
- [ ] Task 3: Execute full private E2E suite (requires authenticated runtime)

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Ghostty AX tree shape changes | Medium | recursive traversal over generic AX attributes + multiple text attributes |
| Accessibility permission missing | High | explicit helper error with setup guidance |
| Helper binary unavailable on host | Medium | script emits explicit missing-helper error |
| Non-macOS usage path | Low | explicit unsupported stub return |

## Success Criteria

- `mung-ghostty-focus` exists and accepts selector input via CLI/env fallback.
- `mung-notify` includes selector in `on_click` payload and tags Ghostty selector flows as `pi-focus-tier-exact`.
- Ghostty selector path retries once then fails with actionable error.
- Existing `mung` test suite remains green.

## Current Verification Snapshot

- [x] `swift build`
- [x] `swift test` (207 passing)
- [x] `bash -n ../skills-for-ai/private/pi/mung-notify/scripts/mung-focus.sh`
- [ ] `vitest` private Pi E2E run (not executed in this session)
