---
status: accepted
date: 2026-11-07
deciders: maintainer
---
# 0011. One package for UI-independent code, the rest in the app

## Context and problem statement

The package split into `NewTubeCore` and `NewTube` existed to share code between iOS, Mac,
tvOS and extension targets. After ADR-0010 only one app consumes it, so a package around the UI layer
isolates nothing. It costs `public` on every shared declaration and a resource bundle separate from
the app's. Core had also picked up view models and SwiftUI and AVFoundation imports.

## Decision

`NewTubeCore` is the only package: models, API clients, stores and decision logic that don't need
UI or AVFoundation. Views, view models and services live in the `NewTube` app target (module
`NewTube`). Tests go next to the code they need: `NewTubeCore/Tests` or the hosted
`NewTubeApp/NewTubeTests`. Add another package only when code has a second consumer or a boundary
the compiler should enforce.

## Consequences
- Good: the compiler stops Core from depending on the app, and most tests run without an app host.
- Good: the app's string catalog is in the main bundle, where SwiftUI `Text` looks by default.
- Bad: tests of view models are hosted, so the app needs an empty scene for test runs.
- Bad: one Core test (`LocalSubscriptionFeedServiceTests`) lives in the app test target, because it
  shares `MockInnerTubeAPI` with the view model tests.

## Alternatives considered
- No package at all: loses the enforced boundary and makes all tests hosted.
- More packages (player, stream resolution): no second consumer, and playback is still being
  decomposed (WS4), so the boundaries would be guesses.
