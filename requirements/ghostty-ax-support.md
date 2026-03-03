## Clarification Summary

### Before (Original)
"I have a idea.
Could you read this?
currently mung and mung-notify in skills-for-ai is not supported ghossty
what about using macOS Accessiblity API?
for the ghossty, do special case."

(plus a Swift/AppKit/ApplicationServices AX snippet for finding Ghostty process, reading windows/tabs, and activating target via `AXPress`)

### After (Clean Spec)
- **Goal**: Add Ghostty-specific support to activate a target tab/pane using macOS Accessibility API before running workflow logic.
- **Scope In**:
  - Support **both** `mung` and `mung-notify`
  - Implement as a **shared helper**
  - Use a **Swift helper binary** (`AppKit` + `ApplicationServices`)
  - Target selection via **CLI flag** (e.g. `--target <selector>`) with **env fallback**
  - Ghostty targeting via AX traversal and activation (`AXPress`)
  - Failure policy: **retry once, then fail**
  - Architecture: keep a **cross-platform stub abstraction** (macOS backend implemented now)
- **Scope Out**:
  - Non-Ghostty terminal feature expansion
  - Full non-macOS implementation (stub only for now)
- **Constraints**:
  - Must use macOS Accessibility APIs
  - Requires Accessibility permission handling in runtime behavior
- **Success Criteria**:
  - For Ghostty on macOS, matching target is activated reliably from selector input
  - Shared helper is reused by both `mung` and `mung-notify`
  - On failure, one retry occurs; then exits non-zero with clear error
- **Priority/Timeline**: **Not specified yet**

### Decisions Made

| Topic | Decision |
|---|---|
| Primary objective | Tab/pane switching via Accessibility API |
| Scope | Both `mung` + `mung-notify` (shared helper) |
| Implementation | Swift helper binary |
| Target matching | Configurable selector |
| Selector input | CLI flag + env fallback |
| Failure behavior | Retry once, then fail |
| Platform strategy | Stub abstraction; macOS backend now |

### Resolved Implementation Notes
- Selector grammar supports: `exact` / `prefix` / `contains` / `regex` / `glob` via `--match` (defaults to `exact`; wildcard selector auto-uses `glob` when mode omitted).
- Selector input names:
  - CLI: `--target <selector>`
  - Env fallback: `MUNG_GHOSTTY_TARGET` (alias: `PI_MUNG_GHOSTTY_SELECTOR`)
