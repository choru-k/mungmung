# Task 01 — Foundation

## Goal

Add small foundational pieces needed by the UI layer.

## Changes

### 1. `Alert` — add `Hashable`

In `Sources/MungMung/Models/Alert.swift`, change the struct declaration to:

```swift
struct Alert: Codable, Identifiable, Hashable {
```

All stored properties are already value types, so synthesised `Hashable` works.

### 2. `Notification.Name` extension

Create `Sources/MungMung/UI/Notifications+Extensions.swift`:

```swift
import Foundation

extension Notification.Name {
    static let alertsDidChange = Notification.Name("mungmung.alertsDidChange")
}
```

This notification is posted by `Commands.add` / `Commands.done` / `Commands.clear`
so the menu bar UI can refresh immediately instead of waiting for the next poll.

## Done when

- `Alert` conforms to `Hashable`
- `Notification.Name.alertsDidChange` compiles
