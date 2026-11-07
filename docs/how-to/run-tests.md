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
  maintainer tests manually. `SmartTubeTVUITests` is disabled in `SmartTube.xctestplan`; set
  `"enabled"` back to `true` there to bring it back. These tests may be out of date until then.

## Target simulator

`just` uses the simulator named in the `justfile` (`Apple TV 4K (4th generation)`). Override it with
the `SMARTTUBE_TV_SIM` environment variable.

### One-time simulator setup

Disable the crash dialog so a mid-test crash doesn't block subsequent tests (persists across
reboots, reset if the simulator is erased):

```bash
xcrun simctl boot "Apple TV 4K (4th generation)" 2>/dev/null
xcrun simctl spawn "Apple TV 4K (4th generation)" defaults write com.apple.CrashReporter DialogType none
```

## Memory ceiling

16 GB Mac Mini. Each simulator clone adds ~500–750 MB RAM (copy-on-write). **3 workers is the
ceiling** — 5 stalls clone boot indefinitely with no output. `justfile` hardcodes 3; don't raise
it without more RAM.

## Commands

- `just test-unit` — Swift Testing package tests on the tvOS simulator. `swift test` can't build
  them, because the `SmartTubeIOS` target needs UIKit and SwiftPM builds for the host Mac.
- `just test-unit-filter <Suite>` — one suite.
- `just test-ui` — UI tests, 3 parallel workers (enable them in the test plan first).
- `just test-ui-one <SmartTubeTVUITests/Suite/testMethod>` — a single UI test.
- Device/app log capture during a test run: `docs/how-to/device-logs.md`.

## Known failures

These fail independently of any recent change:

- Keychain persistence tests (`TokenManager`, Brand Account `pageId`): the unsigned test host has no
  Keychain access.
- Home/Recommended Shorts tests (`homeShortsVideos`, `loadMoreShortsIfNeeded`, `preloadMoreShorts`,
  `recommendedShortsVideos`): they still expect Shorts in those feeds, which tvOS removed.
- `fetchShorts sends TVHTML5 clientName`: `fetchShorts` now uses the WEB search path.
- `SubscriptionsSortTests` pagination test: page 1 hasn't loaded after its fixed 50 ms wait.
- Now Playing command and audio interruption tests are timing-dependent and vary between runs.
