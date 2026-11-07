# SmartTube — agent guide

Native Swift/SwiftUI YouTube client for tvOS (27+) only; see ADR-0010. The `SmartTubeIOS` names are
historical. Package `SmartTubeIOS/` (targets `SmartTubeIOSCore` = Foundation-only models/API/stores,
`SmartTubeIOS` = SwiftUI views, view models, services) + Xcode project `SmartTubeApp/`
(`Smart Tube` tvOS app, `SmartTubeTVUITests`).
Architecture map: docs/architecture.md · Glossary: CONTEXT.md · Decisions: docs/adr/ · Plan: docs/modernization/

## Commands (always via `just`; run `just` to list)
- `just ci` — secrets check + format check + lint + unit tests. Run after finishing a larger task, not before every commit.
- `just build` — tvOS simulator build, no signing needed.
- `just test-unit` / `just test-unit-filter <Name>` — Swift Testing package tests on the tvOS simulator.
- `just test-ui` — UI tests (needs a signed-in simulator; 3 workers max, see docs/how-to/run-tests.md).
- `just format` — swift-format in place. `just lint` — SwiftLint against the committed baseline.

## When to run tests
- Unit tests: only after finishing a larger task. During a task, compile the affected target instead.
- UI tests: don't run them while navigation and large parts of the app are being reworked; the maintainer tests manually. They're disabled in `SmartTube.xctestplan` and may be out of date.

## Rules that differ from defaults
- Swift 6 strict concurrency everywhere. View models are `@MainActor @Observable`. No `ObservableObject`, `@Published`, Combine, `DispatchQueue`, completion handlers in new code.
- `SmartTubeIOSCore` must stay Foundation-only (no SwiftUI/UIKit/AVFoundation). Put platform code in `SmartTubeIOS`.
- One definition per constant/identifier/threshold. Accessibility identifiers come from `AccessibilityID`; SF Symbols from `AppSymbol`; playback timeouts from `PlaybackTuning`.
- tvOS only: no `#if os(...)` branches, and no APIs tvOS lacks (WebKit, WidgetKit, ActivityKit). Never nest `NavigationStack`s.
- The project is `SmartTubeApp.xcodeproj/project.xcproj` (JSON) and may be edited directly. New Swift files under the `Smart Tube` folder and the package are picked up automatically; UI-test files must be listed in the project file.
- Tests: Swift Testing for unit tests; no `Task.sleep`, no live network, fakes at protocol seams. UI tests use `AccessibilityID` and `waitForExistence`, never `sleep`.
- Logging via `AppLogger` (or `os.Logger` with subsystem `appSubsystem`), never `print`.
- Commits: Conventional Commits with the task ID, e.g. `fix(player): … (#312)`.

## Gotchas
- The Simulator cannot decode VP9/AV1; assert stream *selection* in tests, not decoding.
- `swift test` can't build the package: the UI target needs UIKit and SwiftPM builds for the host Mac. Use `just test-unit`.
- The InnerTube `iOS` client profile and its user agent are API identities, not platform code. Don't remove them.
- Authenticated InnerTube calls use the TVHTML5 client on youtubei.googleapis.com with a Bearer token and no API key; the WEB client rejects Bearer tokens. Never call `/oauth2/v3/userinfo` for account info (the TV OAuth client isn't Data-API-v3-enabled) — use `account/accounts` with the TVHTML5 context instead.
- The 16 GB build Mac stalls with > 3 parallel simulator clones; `just` hardcodes 3.
- Playback fallback code (`PlaybackViewModel+Fallback.swift`) is under active decomposition (WS4). Do not add branches there; add a `StreamSource`.

## Where things are
- Playback: docs/architecture.md#playback · Tests how-to: docs/how-to/run-tests.md · Device logs: docs/how-to/device-logs.md
- Tasks: tasks/README.md (open items) · Modernization program: docs/modernization/PLAN.md
