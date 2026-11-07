> status: current (2026-09-11)

# How to capture device/app logs

**When to use:** debugging a test failure/skip, or investigating runtime behavior (quality
switches, network calls, stats snapshots) — anything where you need to see what the app actually
logged, not just whether an assertion passed.

## From a test run (simulator, deterministic)

`xcodebuild` does not write app `Logger` output to stdout. Use `-resultBundlePath` and extract with
`xcresulttool`:

```bash
RESULT=/tmp/newtube-test-$(date +%s).xcresult
xcodebuild test \
  -workspace NewTube.xcworkspace -scheme NewTube \
  -destination "id=<SIMULATOR_UDID>" \  # see docs/how-to/run-tests.md#target-simulator
  -only-testing:NewTubeUITests/<SuiteClass>/<testMethod> \
  -resultBundlePath "$RESULT" 2>&1 | tee /tmp/newtube-test-xcodebuild.log

LOG_DIR=/tmp/newtube-diag-$(date +%s)
xcrun xcresulttool export diagnostics --path "$RESULT" --output-path "$LOG_DIR"
APP_LOG=$(find "$LOG_DIR" -name "*newtube*" -o -name "*com.void*" 2>/dev/null | grep -v "Runner\|UITests" | head -1)
wc -l "$APP_LOG"
```

**Do NOT use `log stream`** for this — it's unreliable (the simulator can be shut down before the
stream starts, timing races cause truncation). `-resultBundlePath` is atomic and reliable.

Full grep patterns for quality-switch events, network/playback events, and skip classification:
`.github/skills/ui-tests-with-logs/SKILL.md` (private repo).

## From a physical device (live, manual reproduction)

For an **intermittent bug that scripted UI taps can't reproduce** after several attempts, live
manual reproduction with terminal log streaming is faster than more scripted attempts or fighting
Console.app's GUI (its process/message filter dropdown is unreliable to drive via clicks).

```bash
brew install libimobiledevice
idevice_id -l   # note: a DIFFERENT UDID format than `xcrun devicectl list devices` —
                 # devicectl's identifier does not work with idevicesyslog
idevicesyslog -u <idevice_id-format-UDID> > /tmp/capture.log 2>&1 &
# ask the user to reproduce the bug manually on the device, then:
pkill -f idevicesyslog
grep <relevant-tag> /tmp/capture.log
```

A cabled connection is more stable than wireless for repeated `xcodebuild test` runs against a
physical device.

## `AGENT-POST-RUN-CHECK` marker

Tests that require log inspection after every run carry a structured comment block at the top of
their file (`// AGENT-POST-RUN-CHECK: ui-tests-with-logs`). When running such a test, always
extract the device log and classify every skip before considering the task done — see
`.github/skills/ui-tests-with-logs/SKILL.md` (private repo) for the marker standard.
