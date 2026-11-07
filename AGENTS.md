# SmartTube — agent guide

Native Swift/SwiftUI YouTube client for tvOS (27+) only; see ADR-0010. Package `SmartTubeCore/` holds
UI-independent models, API clients and stores. Xcode project `SmartTubeApp/` holds everything else:
`Smart Tube` (tvOS app: views, view models, services; module `SmartTube`), `SmartTubeTests` (hosted
unit tests), `SmartTubeTVUITests`. See ADR-0011 before adding a package.
Architecture map: docs/architecture.md · Glossary: CONTEXT.md · Decisions: docs/adr/ · Plan: docs/modernization/

## Commands (always via `just`; run `just` to list)
- `just ci` — secrets check + format check + lint + unit tests. Run after finishing a larger task, not before every commit.
- `just build` — tvOS simulator build, no signing needed.
- `just test-unit` — all unit tests on the tvOS simulator (`just test-core` + `just test-app`).
- `just test-core-filter <Name>` / `just test-app-filter <Name>` — one suite.
- `just test-ui` — UI tests (needs a signed-in simulator; 3 workers max, see docs/how-to/run-tests.md).
- `just format` — swift-format in place. `just lint` — SwiftLint against the committed baseline.

## When to run tests
- Unit tests: only after finishing a larger task. During a task, compile the affected target instead.
- UI tests: don't run them while navigation and large parts of the app are being reworked; the maintainer tests manually. They're disabled in `SmartTube.xctestplan` and may be out of date.

## Rules that differ from defaults
- Swift 6 strict concurrency everywhere. View models are `@MainActor @Observable`. No `ObservableObject`, `@Published`, Combine, `DispatchQueue`, completion handlers in new code.
- `SmartTubeCore` must stay UI-independent (no SwiftUI/UIKit/AVFoundation). View models and platform code go in the app.
- Tests go in `SmartTubeCore/Tests` when they only need Core, in `SmartTubeApp/SmartTubeTests` when they need the app.
- One definition per constant/identifier/threshold. Accessibility identifiers come from `AccessibilityID`; SF Symbols from `AppSymbol`; playback timeouts from `PlaybackTuning`.
- tvOS only: no `#if os(...)` branches, and no APIs tvOS lacks (WebKit, WidgetKit, ActivityKit). Never nest `NavigationStack`s.
- The project is `SmartTubeApp.xcodeproj/project.xcproj` (JSON) and may be edited directly. New files under the `Smart Tube` and `SmartTubeTests` folders and the package are picked up automatically; UI-test files must be listed in the project file.
- App-level navigation goes through `AppNavigator` (ADR-0012): no per-view `navigationDestination(item:)`, navigation notifications, or player presented from a tab.
- Tests: Swift Testing for unit tests; no `Task.sleep`, no live network, fakes at protocol seams. UI tests use `AccessibilityID` and `waitForExistence`, never `sleep`.
- Logging via `AppLogger` (or `os.Logger` with subsystem `appSubsystem`), never `print`.
- Commits: Conventional Commits with the task ID, e.g. `fix(player): … (#312)`.

## Gotchas
- The Simulator cannot decode VP9/AV1; assert stream *selection* in tests, not decoding.
- `swift test` isn't supported: the package only declares tvOS and SwiftPM builds for the host Mac. Use `just test-unit`.
- The InnerTube `iOS` client profile and its user agent are API identities, not platform code. Don't remove them.
- Authenticated InnerTube calls use the TVHTML5 client on youtubei.googleapis.com with a Bearer token and no API key; the WEB client rejects Bearer tokens. Never call `/oauth2/v3/userinfo` for account info (the TV OAuth client isn't Data-API-v3-enabled) — use `account/accounts` with the TVHTML5 context instead.
- The 16 GB build Mac stalls with > 3 parallel simulator clones; `just` hardcodes 3.
- Playback fallback code (`PlaybackViewModel+Fallback.swift`) is under active decomposition (WS4). Do not add branches there; add a `StreamSource`.

- The `.sidebarAdaptable` `TabView` discards a tab's `@State` when another tab is selected, and evaluates every tab's content on each selection change. State that must survive tab switches goes in `AppFeeds`; don't do work in the initializer of a tab's root view.

- Text input doesn't work in the tvOS 27.2 Simulator, even in Apple's Settings app: selecting a key dismisses the keyboard or moves focus away. Test search and other text entry on a real Apple TV.

## Where things are
- Playback: docs/architecture.md#playback · Tests how-to: docs/how-to/run-tests.md · Device logs: docs/how-to/device-logs.md
- Tasks: tasks/README.md (open items) · Modernization program: docs/modernization/PLAN.md
