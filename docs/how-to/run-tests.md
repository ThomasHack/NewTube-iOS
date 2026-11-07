> status: current (2026-09-11)

# How to run tests

**When to use:** running unit or UI tests locally, or setting up a fresh simulator.

Don't use
`mcp_xcode_RunAllTests`/`mcp_xcode_RunSomeTests` or any other `mcp_xcode_*` tool to run tests.

## When to run tests

Tests take a lot of time, so run them deliberately:

- **Unit tests:** only after finishing a larger task. During a task, compiling the affected target
  is enough.
- **UI tests:** not during the current rework of navigation and large parts of the app. The
  maintainer tests manually. `NewTubeTVUITests` is disabled in `NewTube.xctestplan`; set
  `"enabled"` back to `true` there to bring it back. These tests may be out of date until then.

## Target simulator

The commands below use `Apple TV 4K (4th generation)`.

### One-time simulator setup

Disable the crash dialog so a mid-test crash doesn't block subsequent tests (persists across
reboots, reset if the simulator is erased):

```bash
xcrun simctl boot "Apple TV 4K (4th generation)" 2>/dev/null
xcrun simctl spawn "Apple TV 4K (4th generation)" defaults write com.apple.CrashReporter DialogType none
```

## Memory ceiling

16 GB Mac Mini. Each simulator clone adds ~500–750 MB RAM (copy-on-write). **3 workers is the
ceiling** — 5 stalls clone boot indefinitely with no output. Pass `-parallel-testing-worker-count 3`, and don't
raise it without more RAM.

## Commands

```bash
# NewTubeTests, hosted by the app. The host launches an empty scene, so a test run doesn't start
# sign-in or network work. Add /<Suite> for one suite.
xcodebuild test -workspace NewTube.xcworkspace -scheme "NewTube" \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (4th generation)" -only-testing:NewTubeTests CODE_SIGNING_ALLOWED=NO

# NewTubeCore tests, which run without the app. `swift test` isn't supported, because the package
# only declares tvOS and SwiftPM builds for the host Mac.
cd NewTubeCore && xcodebuild test -scheme NewTubeCore \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (4th generation)" CODE_SIGNING_ALLOWED=NO
```

- Device/app log capture during a test run: `docs/how-to/device-logs.md`.

## Keychain

The test process has no Keychain entitlement, so `SecItemAdd` returns `-34018`, signed or not.
`TokenManager` tests use `InMemoryTokenStore`, which means `KeychainTokenStore` itself has no unit test.
