# Menu Bar UI for MungMung

## Overview

Add a native macOS menu bar icon to MungMung so the app has a visible presence when running.
Running `mung` with no arguments launches a SwiftUI `MenuBarExtra` that shows pending alerts
in a popover. CLI commands (`mung add`, `mung list`, etc.) continue to work as before.

## Architecture

- **Entry point split**: `@main enum MungMungEntry` checks `CommandLine.arguments`.
  - Args present -> CLI path (parse & route, then `exit(0)`)
  - No args -> `MungMungApp.main()` (SwiftUI run loop, menu bar icon)
- **SwiftUI App**: `struct MungMungApp: App` with a single `MenuBarExtra` scene (`.window` style).
- **ViewModel**: `@MainActor @Observable AlertViewModel` polls `AlertStore` every 2 seconds.
- **AppDelegate**: `@NSApplicationDelegateAdaptor` handles notification clicks without `exit(0)`.

## Tasks

1. [task-01-foundation.md](task-01-foundation.md) — Notification.Name extension + Hashable on Alert
2. [task-02-view-model.md](task-02-view-model.md) — AlertViewModel
3. [task-03-ui-views.md](task-03-ui-views.md) — MenuBarLabel, AlertRowView, MenuBarContentView
4. [task-04-entry-point.md](task-04-entry-point.md) — Rewrite MungMungApp.swift
5. [task-05-build-verify.md](task-05-build-verify.md) — Build, test, manual verification
