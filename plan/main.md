# mungmung — Implementation Plan

A native macOS app that manages stateful notifications via CLI (`mung`). No terminal-notifier — built from scratch with Swift and `UNUserNotificationCenter`.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        mung CLI                             │
│                   CommandLine.arguments                      │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│   add    │   done   │   list   │  count   │  clear/ver/help │
├──────────┴──────────┴──────────┴──────────┴─────────────────┤
│                                                             │
│  ┌──────────────┐  ┌────────────────────┐  ┌─────────────┐ │
│  │  AlertStore   │  │NotificationManager │  │ ShellHelper │ │
│  │              │  │                    │  │             │ │
│  │ CRUD on JSON │  │UNUserNotification  │  │ on_click    │ │
│  │ state files  │  │Center wrapper      │  │ sketchybar  │ │
│  └──────┬───────┘  └────────┬───────────┘  └──────┬──────┘ │
│         │                   │                      │        │
│         ▼                   ▼                      ▼        │
│  ~/.local/share/       macOS Notification    shell commands  │
│  mung/alerts/*.json    Center                               │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│              AppDelegate (UNUserNotificationCenterDelegate)  │
│              handles notification click → on_click → done    │
└─────────────────────────────────────────────────────────────┘
```

## Lifecycle

1. User runs `mung add ...` → app launches, sends notification, writes state, triggers sketchybar, exits
2. User clicks notification → macOS relaunches app → AppDelegate extracts action from `userInfo` → executes `on_click` → removes state → triggers sketchybar → exits
3. User runs `mung done <id>` → removes state + notification → triggers sketchybar → exits
4. No daemon. No background process. Launch-on-demand only.

## Source Structure

```
MungMung/
├── Package.swift
├── Sources/MungMung/
│   ├── MungMungApp.swift              # @main, AppDelegate, entry point
│   ├── Models/
│   │   └── Alert.swift                # Alert struct (Codable)
│   ├── Services/
│   │   ├── AlertStore.swift           # JSON state file CRUD
│   │   ├── NotificationManager.swift  # UNUserNotificationCenter wrapper
│   │   └── ShellHelper.swift          # Run shell commands (on_click, sketchybar)
│   └── CLI/
│       ├── CLIParser.swift            # Argument parser + router
│       └── Commands.swift             # add, done, list, count, clear, version, help
├── Resources/
│   └── Info.plist                     # LSUIElement=true, bundle config
├── MungMung.entitlements
├── Scripts/
│   ├── distribute.sh                  # Sign + notarize + GitHub release
│   └── create_dmg.sh                  # DMG packaging
├── Casks/
│   └── mungmung.rb                    # Homebrew cask formula
├── examples/
│   └── sketchybar-plugin.sh           # Reference sketchybar plugin
└── Makefile
```

## Task Index

| # | Task | Dependencies | Files |
|---|------|-------------|-------|
| 1 | [Project Setup & App Scaffold](task-01-project-setup.md) | None | Package.swift, Info.plist, entitlements, MungMungApp.swift, Makefile |
| 2 | [Alert Model & State Store](task-02-alert-model-state-store.md) | Task 1 | Alert.swift, AlertStore.swift |
| 3 | [CLI Argument Parser](task-03-cli-parser.md) | Task 1 | CLIParser.swift |
| 4 | [Notification Manager](task-04-notification-manager.md) | Task 1 | NotificationManager.swift |
| 5 | [Command Implementations](task-05-commands.md) | Tasks 2, 3, 4, 7 | Commands.swift, MungMungApp.swift (update) |
| 6 | [Notification Click Handler](task-06-notification-click-handler.md) | Tasks 2, 4, 7 | MungMungApp.swift (update) |
| 7 | [Shell Helper & Sketchybar Integration](task-07-sketchybar-example.md) | Task 1 | ShellHelper.swift, examples/sketchybar-plugin.sh |
| 8 | [Build & Distribution](task-08-build-distribution.md) | Tasks 1-7 | Scripts/distribute.sh, Scripts/create_dmg.sh, Casks/mungmung.rb |
| 9 | [Protocols & DI Refactor](task-09-protocols-di-refactor.md) | Tasks 4, 5, 7 | Protocols.swift, NotificationManager.swift, ShellHelper.swift, Commands.swift |
| 10 | [Update Call Sites](task-10-update-call-sites.md) | Task 9 | CLIParser.swift, MungMungApp.swift, Makefile |
| 11 | [Test Mocks](task-11-test-mocks.md) | Task 9 | Mocks.swift |
| 12 | [Commands Unit Tests](task-12-commands-unit-tests.md) | Tasks 10, 11 | CommandsTests.swift |
| 13 | [CLI Integration Tests](task-13-cli-integration-tests.md) | Task 10 | CLIIntegrationTests.swift |

## Testing Plan (Tasks 9-13)

### Phase 1: Refactor for Testability (Tasks 9-10)
- **Task 9:** Create protocols + conform types + refactor Commands to return exit codes with DI
- **Task 10:** Update CLIParser and MungMungApp call sites + Makefile

### Phase 2: Test Infrastructure (Task 11)
- **Task 11:** Create mock implementations for testing

### Phase 3: Write Tests (Tasks 12-13)
- **Task 12:** ~25 Commands unit tests
- **Task 13:** ~22 CLI integration tests

### Execution Plan

**Batch 1:** Task 9
**Checkpoint:** `swift build` compiles clean

**Batch 2:** Tasks 10, 11 (independent)
**Checkpoint:** `swift build && swift test` — all 45 existing tests pass

**Batch 3:** Tasks 12, 13 (independent)
**Checkpoint:** `swift build && swift test` — ~92 total tests pass

### Final Verification
- [ ] All ~92 tests pass
- [ ] No behavioral regressions: `mung help`, `mung version`, add/list/clear cycle works
- [ ] Existing 45 tests unaffected

## Dependency Graph

```
Task 1 (Project Setup)
  ├── Task 2 (Alert Model & Store)
  │     └──┐
  ├── Task 3 (CLI Parser)
  │     └──┤
  ├── Task 4 (Notification Manager)
  │     └──┤
  └── Task 7 (Shell Helper & Sketchybar)
        └──┤
           ├── Task 5 (Commands) ──────┐
           │                           ├── Task 8 (Build & Distribution)
           └── Task 6 (Click Handler) ─┘

Task 5 (Commands) + Task 4 + Task 7
  └── Task 9 (Protocols & DI Refactor)
        ├── Task 10 (Update Call Sites) ──┐
        │                                 ├── Task 12 (Commands Unit Tests)
        └── Task 11 (Test Mocks) ─────────┘
        └── Task 10 ──── Task 13 (CLI Integration Tests)
```

**Tasks 1-8:** Core implementation (complete).
**Tasks 9-10:** Refactor for testability.
**Tasks 11-13:** Test infrastructure and test suites.

## Key Decisions

- **No external dependencies** — hand-rolled CLI parser, no ArgumentParser package. The CLI is simple (7 subcommands with a few flags each).
- **SPM executable target** — same pattern as PasteFence. `swift build` produces a single binary.
- **State files are plain JSON** — any tool (shell scripts, sketchybar plugins) can read them.
- **ID format: `{unix_timestamp}_{8_hex_chars}`** — sortable, unique, human-readable.
- **macOS 14+ (Sonoma)** — matches PasteFence, ensures modern UNUserNotificationCenter APIs.
- **Developer ID:** `Developer ID Application: Cheol Kang (ESURPGU29C)`
- **Bundle ID:** `com.choru-k.mungmung`

## References

| Reference | Path |
|-----------|------|
| SPEC | `~/Desktop/choru/mungmung/SPEC.md` |
| PasteFence Package.swift | `~/Desktop/choru/pastefence/Package.swift` |
| PasteFence Info.plist | `~/Desktop/choru/pastefence/Resources/Info.plist` |
| PasteFence Makefile | `~/Desktop/choru/pastefence/Makefile` |
| PasteFence distribute.sh | `~/Desktop/choru/pastefence/Scripts/distribute.sh` |
| PasteFence create_dmg.sh | `~/Desktop/choru/pastefence/Scripts/create_dmg.sh` |
| PasteFence cask formula | `~/Desktop/choru/pastefence/Casks/pastefence.rb` |
| PasteFence entitlements | `~/Desktop/choru/pastefence/PasteFence/PasteFence/PasteFence.entitlements` |
| Sketchybar ai_sessions.sh | `~/dotfiles/sketchybar/plugins/ai_sessions.sh` |
| Sketchybar sketchybarrc | `~/dotfiles/sketchybar/sketchybarrc` |
