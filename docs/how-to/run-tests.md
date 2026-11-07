> status: current (2026-09-11)

# How to run tests

**When to use:** running unit or UI tests locally, or setting up a fresh simulator.

All commands are `just` recipes (run `just` from the repo root to list them). Don't use
`mcp_xcode_RunAllTests`/`mcp_xcode_RunSomeTests` or any other `mcp_xcode_*` tool to run tests.

## When to run tests

Tests take a lot of time, so run them deliberately:

- **Unit tests:** only after finishing a larger task. During a task, compiling the affected target
  is enough.
- **UI tests:** not during the current rework of navigation and large parts of the app. The
  maintainer tests manually. `SmartTubeUITests` is disabled in `SmartTube.xctestplan`; set
  `"enabled"` back to `true` there to bring it back. These tests may be out of date until then.

## Target simulator

Single source of truth for the iOS/Catalyst target simulator — don't copy this UDID into other
docs, link here instead.

| Property | Value |
|---|---|
| Name | iPhone 17 |
| UDID | `6CEE2FAC-7D50-4BD0-95E2-1361EDD7FAF6` |
| OS | iOS 26.4.1 |

### One-time simulator setup

Disable the crash dialog so a mid-test crash doesn't block subsequent tests (persists across
reboots, reset if the simulator is erased):

```bash
xcrun simctl boot 6CEE2FAC-7D50-4BD0-95E2-1361EDD7FAF6 2>/dev/null; sleep 3
xcrun simctl spawn 6CEE2FAC-7D50-4BD0-95E2-1361EDD7FAF6 \
  defaults write com.apple.CrashReporter DialogType none
```

Verify: `xcrun simctl spawn 6CEE2FAC-7D50-4BD0-95E2-1361EDD7FAF6 defaults read com.apple.CrashReporter DialogType` should print `none`.

## Memory ceiling

16 GB Mac Mini. Each simulator clone adds ~500–750 MB RAM (copy-on-write). **3 workers is the
ceiling** — 5 stalls clone boot indefinitely with no output. `justfile` hardcodes 3; don't raise
it without more RAM.

## Commands

- `just test-unit` — Swift Testing package tests, no simulator.
- `just test-ui-legacy` — UI tests, 3 parallel workers. Temporary until WS3-T3.4 adds the
  `Smoke`/`Live` test plans, at which point `just test-smoke`/`just test-ui` take over.
- `just test-ui-one <SmartTubeUITests/Suite/testMethod>` — a single UI test.
- Device/app log capture during a test run: `docs/how-to/device-logs.md`.

## Known failure

`just test-unit` currently fails to build (pre-existing, not test-writing-related) — see
`AGENTS.md`'s Gotchas. Native-macOS-only code in `TOSPlayerView.swift`/
`TOSPlayerViewModel+WebBridge.swift` doesn't compile. Fixing it is WS4/WS5 scope.
