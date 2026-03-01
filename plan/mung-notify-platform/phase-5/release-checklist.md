---
type: checklist
phase: 5
status: done
updated-at: 2026-03-01
---

# Release Hardening Checklist

## Artifacts
- Root changelog: `CHANGELOG.md`
- Release runbook: `RELEASE_PREP.md`

## Pre-release
- [x] `swift test`
- [x] `swift build -c release`
- [x] `make verify-release`
- [x] Validate `mung help` includes: metadata flags, `--dedupe-key`, `doctor`, diagnostics env vars.
- [x] Validate `mung doctor --json` includes: notification availability, state paths/counts, action shell context.
- [x] Validate reference flows in `CLIIntegrationTests`:
  - Pi update/action lane behavior
  - Claude session isolation

## Packaging + Distribution
- [ ] Build distributable artifacts (`make release VERSION=x.y.z`)
- [ ] Verify app bundle launch + menu bar behavior manually
- [ ] Verify CLI symlink/path behavior from Homebrew install

## Post-release smoke checks
- [ ] `mung add --title "Smoke" --message "Hello" --source pi-agent --session smoke --kind update --dedupe-key pi:update:smoke`
- [ ] `mung list --session smoke --json`
- [ ] `mung done <id> --run` (when `on_click` is present)
- [ ] `mung clear --source pi-agent --session smoke`
- [ ] Confirm sketchybar event path updates as expected

## Troubleshooting quick refs
- Enable action diagnostics: `MUNG_DEBUG_ACTIONS=1`
- Enable lifecycle diagnostics: `MUNG_DEBUG_LIFECYCLE=1`
- Inspect runtime assumptions: `mung doctor --json`
