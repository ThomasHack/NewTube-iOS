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

- `just test-unit` — all Swift Testing unit tests on the tvOS simulator. `swift test` isn't
  supported, because the package only declares tvOS and SwiftPM builds for the host Mac.
- `just test-core` — `SmartTubeCore` tests, which run without the app.
- `just test-app` — `SmartTubeTests`, hosted by the app. The host launches an empty scene, so a test
  run doesn't start sign-in or network work.
- `just test-core-filter <Suite>` / `just test-app-filter <Suite>` — one suite.
- `just test-ui` — UI tests, 3 parallel workers (enable them in the test plan first).
- `just test-ui-one <SmartTubeTVUITests/Suite/testMethod>` — a single UI test.
- Device/app log capture during a test run: `docs/how-to/device-logs.md`.

## Keychain

The test process has no Keychain entitlement, so `SecItemAdd` returns `-34018`, signed or not.
`TokenManager` tests use `InMemoryTokenStore`, which means `KeychainTokenStore` itself has no unit test.
