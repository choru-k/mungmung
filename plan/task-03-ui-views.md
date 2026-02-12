# Task 03 — UI Views

## Goal

Create the three SwiftUI views for the menu bar popover.

## Files

### 1. `Sources/MungMung/UI/MenuBarLabel.swift`

- Shows a dog emoji or SF Symbol as the menu bar icon
- Badge count overlay when alerts > 0

### 2. `Sources/MungMung/UI/AlertRowView.swift`

- Single alert row: icon, title, message preview, age, dismiss button
- Tapping dismiss calls `viewModel.dismiss(alert)`

### 3. `Sources/MungMung/UI/MenuBarContentView.swift`

- Main popover content
- List of `AlertRowView` when alerts exist
- "No alerts" placeholder when empty
- "Clear All" button in footer

## Done when

- All three views compile
- MenuBarContentView takes an `AlertViewModel` and renders correctly
