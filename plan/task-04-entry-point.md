# Task 04 — Entry Point Rewrite

## Goal

Rewrite `MungMungApp.swift` to support both CLI and menu bar modes.

## Design

### `@main enum MungMungEntry`

```
if CommandLine.arguments.count > 1 {
    // CLI mode — parse, route, exit
} else {
    // GUI mode — launch SwiftUI app
    MungMungApp.main()
}
```

### `struct MungMungApp: App`

- `@NSApplicationDelegateAdaptor` for `AppDelegate`
- `@State private var viewModel = AlertViewModel()`
- Single `Scene`: `MenuBarExtra` with `.window` style
- Label: `MenuBarLabel(count:)`
- Content: `MenuBarContentView(viewModel:)`
- `.onAppear { viewModel.startPolling() }`

### `AppDelegate` (updated)

- Keeps notification click handling
- Removes `exit(0)` — app stays running
- Posts `.alertsDidChange` after handling a click

## Done when

- `mung add --title X --message Y` works (CLI path)
- `mung` with no args shows menu bar icon (GUI path)
