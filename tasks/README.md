# Open items

Remove an item when it's done.

## Tooling
- [ ] Install `just` and run the recipes rewritten in the package restructure: `test-unit`,
  `test-core`, `test-app`, `test-core-filter`, `test-app-filter`. So far only the underlying
  `xcodebuild` commands have been run.
- [ ] Get `swiftlint lint --strict --baseline` passing. It reports 169 violations that aren't in the
  baseline, the same count as before the restructure, so `just ci` fails at its lint step.

## Navigation
- [ ] `ConditionalMoveCommand` (`PlayerView+tvOS.swift`) swaps `if/else` branches, which rebuilds the
  player's view subtree whenever an overlay or skip toast opens. Keep the view's identity stable, and
  check the player's menus and pickers with a remote afterwards.

## Localization
- [ ] Translate "Default Quality" in Settings, which stays English in German.

## Cleanup
- [ ] Delete `yt.solver.lib.min.js` and `yt.solver.core.min.js` from `SmartTubeApp/Smart Tube/Resources/`
  if they're confirmed unused. No code references them, but they still ship in the app.
- [ ] Move `LocalSubscriptionFeedServiceTests` to `SmartTubeCore/Tests`. It tests Core code but sits in
  `SmartTubeApp/SmartTubeTests` because it shares `MockInnerTubeAPI` with the view model tests, so it
  needs its own fake or a shared test-support target.

## Release
- [ ] Publish `tvos-refresh`, which has no remote branch yet: `git push -u origin tvos-refresh`.
