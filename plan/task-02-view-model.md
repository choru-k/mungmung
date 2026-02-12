# Task 02 — AlertViewModel

## Goal

Create the view model that drives the menu bar UI.

## File

`Sources/MungMung/UI/AlertViewModel.swift`

## Design

- `@MainActor @Observable final class AlertViewModel`
- `var alerts: [Alert] = []`
- Polls `AlertStore().list()` every 2 seconds via `Timer.scheduledTimer`
- Also listens for `Notification.Name.alertsDidChange` for immediate refresh
- `func dismiss(_ alert: Alert)` — removes from store, removes notification, triggers sketchybar
- `func clearAll()` — clears store, removes notifications, triggers sketchybar
- `func startPolling()` / `func stopPolling()` lifecycle methods

## Done when

- `AlertViewModel` compiles and can be instantiated
