# NewTube — agent guide

Native Swift/SwiftUI YouTube client for tvOS (27+) only; see ADR-0010. Package `NewTubeCore/` holds
UI-independent models, API clients and stores. Xcode project `NewTubeApp/` holds everything else:
`NewTube` (tvOS app: views, view models, services; module `NewTube`), `NewTubeTests` (hosted
unit tests), `NewTubeTVUITests`. See ADR-0011 before adding a package.
Architecture map: docs/architecture.md · Glossary: CONTEXT.md · Decisions: docs/adr/ · Plan: docs/modernization/

## Commands
- Build: `xcodebuild build -workspace NewTube.xcworkspace -scheme "NewTube" -destination "platform=tvOS Simulator,name=Apple TV 4K (4th generation)" CODE_SIGNING_ALLOWED=NO -quiet`
- App unit tests: the same with `test` and `-only-testing:NewTubeTests`, or `-only-testing:NewTubeTests/<Suite>` for one suite.
- Core unit tests, from `NewTubeCore/`: `xcodebuild test -scheme NewTubeCore -destination "platform=tvOS Simulator,name=Apple TV 4K (4th generation)" CODE_SIGNING_ALLOWED=NO`
- Format: `xcrun swift-format format --in-place --configuration .swift-format <file>`.
- SwiftLint runs as a build phase of the app target. Its findings are warnings.

## When to run tests
- Unit tests: only after finishing a larger task. During a task, compile the affected target instead.
- UI tests: only when asked, because they're slow: the same with `test` and `-only-testing:NewTubeTVUITests`. They inject their Home feed and don't need an account.

## Rules that differ from defaults
- Swift 6 strict concurrency everywhere. View models are `@MainActor @Observable`. No `ObservableObject`, `@Published`, Combine, `DispatchQueue`, completion handlers in new code.
- `NewTubeCore` must stay UI-independent (no SwiftUI/UIKit/AVFoundation). View models and platform code go in the app.
- Tests go in `NewTubeCore/Tests` when they only need Core, in `NewTubeApp/NewTubeTests` when they need the app.
- One definition per constant/identifier/threshold. SF Symbols come from `AppSymbol`; playback timeouts from `PlaybackTuning`.
- tvOS only: no `#if os(...)` branches, and no APIs tvOS lacks (WebKit, WidgetKit, ActivityKit). Never nest `NavigationStack`s.
- The project is `NewTubeApp.xcodeproj/project.xcproj` (JSON) and may be edited directly. New files under the `NewTube` and `NewTubeTests` folders and the package are picked up automatically; UI-test files must be listed in the project file.
- App-level navigation goes through `AppNavigator` (ADR-0012): no per-view `navigationDestination(item:)`, navigation notifications, or player presented from a tab.
- Tests: Swift Testing for unit tests; no `Task.sleep`, no live network, fakes at protocol seams. UI tests find elements by accessibility identifier and use `waitForExistence`, never `sleep`.
- Logging via `AppLogger` (or `os.Logger` with subsystem `appSubsystem`), never `print`.
- Commits: Conventional Commits with the task ID, e.g. `fix(player): … (#312)`.

## Gotchas
- The Simulator cannot decode VP9/AV1; assert stream *selection* in tests, not decoding.
- `swift test` isn't supported: the package only declares tvOS and SwiftPM builds for the host Mac. Use `xcodebuild`, as above.
- The InnerTube `iOS` client profile and its user agent are API identities, not platform code. Don't remove them.
- Authenticated InnerTube calls use the TVHTML5 client on youtubei.googleapis.com with a Bearer token and no API key; the WEB client rejects Bearer tokens. Never call `/oauth2/v3/userinfo` for account info (the TV OAuth client isn't Data-API-v3-enabled) — use `account/accounts` with the TVHTML5 context instead.
- The 16 GB build Mac stalls with > 3 parallel simulator clones, so run UI tests with `-parallel-testing-worker-count 3`.
- Playback fallback code (`PlaybackViewModel+Fallback.swift`) is under active decomposition (WS4). Do not add branches there; add a `StreamSource`.

- The `.sidebarAdaptable` `TabView` discards a tab's `@State` when another tab is selected, and evaluates every tab's content on each selection change. State that must survive tab switches goes in `AppFeeds`; don't do work in the initializer of a tab's root view.

- Text input doesn't work in the tvOS 27.2 Simulator, even in Apple's Settings app: selecting a key dismisses the keyboard or moves focus away. Test search and other text entry on a real Apple TV.

## Where things are
- Playback: docs/architecture.md#playback · Tests how-to: docs/how-to/run-tests.md · Device logs: docs/how-to/device-logs.md
- Tasks: tasks/README.md (open items) · Modernization program: docs/modernization/PLAN.md
