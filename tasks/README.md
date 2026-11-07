# Open items

Remove an item when it's done.

## Cleanup
- [ ] Delete `yt.solver.lib.min.js` and `yt.solver.core.min.js` from `NewTubeApp/NewTube/Resources/`
  if they're confirmed unused. No code references them, but they still ship in the app.
- [ ] Move `LocalSubscriptionFeedServiceTests` to `NewTubeCore/Tests`. It tests Core code but sits in
  `NewTubeApp/NewTubeTests` because it shares `MockInnerTubeAPI` with the view model tests, so it
  needs its own fake or a shared test-support target.

## Release
- [ ] Publish `tvos-refresh`, which has no remote branch yet: `git push -u origin tvos-refresh`.

## Top Shelf
- [ ] Add a Top Shelf extension (`TVTopShelfContentProvider`): rows for the home screen, with a URL
  scheme to open a video directly. It needs an App Group and a shared keychain group to reach the
  app's data and sign-in. Decide which rows to show first; Subscriptions and Continue Watching from
  cached data would load fastest.

## UI tests (last, once everything else is fine)
- [ ] Bring back `NewTubeTVUITests`. It's disabled in `NewTube.xctestplan`, and it's out of date after
  the navigation, player and Shorts changes.
