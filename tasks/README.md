# Open items

Remove an item when it's done.

## Release
- [ ] Push `tvos-refresh`, which is ahead of `origin/tvos-refresh`, and merge it when it's ready.

## Top Shelf
- [ ] Add a Top Shelf extension (`TVTopShelfContentProvider`): rows for the home screen, with a URL
  scheme to open a video directly. It needs an App Group and a shared keychain group to reach the
  app's data and sign-in. Decide which rows to show first; Subscriptions and Continue Watching from
  cached data would load fastest.
