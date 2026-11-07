---
paths: ["**/*.swift"]
---

<!-- synced with AGENTS.md rev 1 -->

- Swift 6 strict concurrency everywhere. View models are `@MainActor @Observable`. No `ObservableObject`, `@Published`, Combine, `DispatchQueue`, completion handlers in new code.
- `SmartTubeIOSCore` must stay Foundation-only (no SwiftUI/UIKit/AVFoundation/WebKit). Put platform code in `SmartTubeIOS`.
- One definition per constant/identifier/threshold. Accessibility identifiers come from `AccessibilityID`; SF Symbols from `AppSymbol`; playback timeouts from `PlaybackTuning`.
- tvOS only: no `#if os(...)` branches, and no APIs tvOS lacks (WebKit, WidgetKit, ActivityKit). Never nest `NavigationStack`s.
- Tests: Swift Testing for unit tests; no `Task.sleep`, no live network, fakes at protocol seams. UI tests use `AccessibilityID` and `waitForExistence`, never `sleep`.
- Logging via `AppLogger` (or `os.Logger` with subsystem `appSubsystem`), never `print`.
