---
paths: ["**/*.swift"]
---

<!-- synced with AGENTS.md rev 1 -->

- Swift 6 strict concurrency everywhere. View models are `@MainActor @Observable`. No `ObservableObject`, `@Published`, Combine, `DispatchQueue`, completion handlers in new code.
- `NewTubeCore` must stay UI-independent (no SwiftUI/UIKit/AVFoundation). View models and platform code go in the app.
- One definition per constant/identifier/threshold. SF Symbols come from `AppSymbol`; playback timeouts from `PlaybackTuning`.
- tvOS only: no `#if os(...)` branches, and no APIs tvOS lacks (WebKit, WidgetKit, ActivityKit). Never nest `NavigationStack`s.
- Tests: Swift Testing for unit tests; no `Task.sleep`, no live network, fakes at protocol seams. UI tests find elements by accessibility identifier and use `waitForExistence`, never `sleep`.
- Logging via `AppLogger` (or `os.Logger` with subsystem `appSubsystem`), never `print`.
