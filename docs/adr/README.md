# Architecture Decision Records

Before proposing an architecture change, read this folder; a rejected idea is re-proposed only
with new evidence. Each ADR is ≤ 40 lines and uses `template.md`'s MADR-minimal format.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-maintainability-baseline.md) | Maintainability baseline | accepted |
| [0002](0002-mvvm-observable-no-tca.md) | MVVM with `@Observable`, no TCA | accepted |
| [0003](0003-no-project-generation.md) | No Tuist/XcodeGen — the `.xcodeproj` is the source of truth | accepted |
| [0004](0004-plain-init-injection.md) | Plain protocol + initializer injection, no DI framework | accepted |
| [0005](0005-stream-source-pipeline.md) | `StreamSource` + `ResolutionPipeline` replace the `exhaustiveRetry` cascade | proposed |
| [0006](0006-tos-player-default-on-ios.md) | TOS-compliant WKWebView player is the default player on iOS | superseded by 0010 |
| [0007](0007-no-hybrid-avplayer-handoff-for-tos.md) | No hybrid AVPlayer handoff for TOS background play / PiP | superseded by 0010 |
| [0008](0008-standby-swap-disabled.md) | Shorts standby-swap "instant swipe" promotion is permanently disabled | superseded by 0010 |
| [0009](0009-docs-live-with-code.md) | Non-secret docs live in the public repo, with code | accepted |
| [0010](0010-tvos-only.md) | tvOS is the only platform | accepted |
| [0011](0011-one-core-package.md) | One package for UI-independent code, the rest in the app | accepted |
| [0012](0012-app-navigator.md) | One navigator; the player covers the tabs | accepted |
| [0013](0013-no-shorts.md) | The app has no Shorts | accepted |
| [0014](0014-system-player.md) | Playback uses the system player | accepted |
