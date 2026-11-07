> status: current (2026-11-07)

# Home Feed Architecture

## Key files

- **API**: [InnerTubeAPI+Browse.swift](../../NewTubeCore/Sources/NewTubeCore/InnerTubeAPI+Browse.swift) (requests), [InnerTubeAPI+VideoRenderers.swift](../../NewTubeCore/Sources/NewTubeCore/InnerTubeAPI+VideoRenderers.swift) (parsing)
- **Models**: [VideoGroup.swift](../../NewTubeCore/Sources/NewTubeCore/VideoGroup.swift) (`VideoGroup`, `BrowseSection`), [Video.swift](../../NewTubeCore/Sources/NewTubeCore/Video.swift)
- **View model**: [BrowseViewModel.swift](../../NewTubeApp/NewTube/ViewModels/BrowseViewModel.swift)
- **Views**: [HomeView.swift](../../NewTubeApp/NewTube/Views/Home/HomeView.swift)

## Models

- `Video.isShort` marks a Short, so it can be filtered out.
- `VideoGroup` holds `videos`, `nextPageToken` and a `layout`: `.row` (horizontal shelf) or `.grid`.
- `BrowseSection.SectionType` lists every section. `defaultSections` are Home, Subscriptions, History,
  Playlists and Channels. `allSections` adds Recommended, Music, Gaming, News, Live, Sports and Watch
  Later.

## API

| Method | Source | Client |
|---|---|---|
| `fetchHome`, `fetchHomeRows` | `FEwhat_to_watch` | TVHTML5 when signed in, otherwise WEB |
| `fetchSubscriptions` | `FEsubscriptions` | TVHTML5 |
| `fetchHistory` | `FEhistory` | TVHTML5 |
| `fetchNews` | Search for `news today` | WEB, no token |

`fetchMusic`, `fetchGaming`, `fetchLive` and `fetchSports` browse `FEmusic_home`, `FEgaming`,
`FElive_home` and `FEsportsau`, and fall back to a search if that fails or returns nothing.

## Shorts detection

The app has no Shorts (ADR-0013), but YouTube mixes them into normal responses, so the parsers still
flag them and every list filters on `Video.isShort`.

- `reelItemRenderer`: always a Short.
- `shortsLockupViewModel`: always a Short. WEB search returns Shorts in this form.
- `lockupViewModel`: a `reelWatchEndpoint`.
- `tileRenderer` (TVHTML5): the `TILE_STYLE_YTLR_SHORTS` style, a `reelWatchEndpoint` or a `SHORTS`
  overlay. Also the `GgIIBQ==` `ustreamerConfig` or a vertical thumbnail, unless the video is known
  to be longer than 180 seconds.
- `videoRenderer`: a `reelWatchEndpoint`, a `SHORTS` overlay, the `GgIIBQ==` `ustreamerConfig` or a
  vertical thumbnail, unless the video is known to be longer than 180 seconds.

## Load flow

The Home tab shows the Recommended section and the Subscriptions tab shows Subscriptions. Each has its
own `BrowseViewModel` in `AppFeeds`, so a feed survives switching tabs.

`BrowseViewModel.fetchSection` loads the section into `videoGroups`. `HomeView.feedContent` then applies
the filters (Shorts, premieres, watched videos) and draws any `.row` groups as shelves and everything
else as a grid. A loaded feed refreshes after `FeedFreshness.refreshInterval`, keeping its videos on
screen until the new ones arrive.

If a page adds no visible video, for example because it only holds Shorts, `HomeView` fetches the next
page until one does or the pages run out.

Recommended uses `fetchHome`, and Subscriptions sorts its first page newest-first. Later pages are
appended without re-sorting, so rows already on screen don't move. `BrowseViewModel` removes duplicates
by video ID.
