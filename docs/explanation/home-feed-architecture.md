> status: current (2026-11-07)

# Home Feed & Shorts Architecture

## Key files

- **API**: [InnerTubeAPI+Browse.swift](../../SmartTubeIOS/Sources/SmartTubeIOSCore/InnerTubeAPI+Browse.swift) (requests), [InnerTubeAPI+VideoRenderers.swift](../../SmartTubeIOS/Sources/SmartTubeIOSCore/InnerTubeAPI+VideoRenderers.swift) (parsing)
- **Models**: [VideoGroup.swift](../../SmartTubeIOS/Sources/SmartTubeIOSCore/VideoGroup.swift) (`VideoGroup`, `BrowseSection`), [Video.swift](../../SmartTubeIOS/Sources/SmartTubeIOSCore/Video.swift)
- **Policy**: [ShortsFeedPolicy.swift](../../SmartTubeIOS/Sources/SmartTubeIOSCore/ShortsFeedPolicy.swift)
- **View models**: [HomeViewModel.swift](../../SmartTubeIOS/Sources/SmartTubeIOSCore/HomeViewModel.swift), [BrowseViewModel.swift](../../SmartTubeIOS/Sources/SmartTubeIOSCore/BrowseViewModel.swift)
- **Views**: [HomeView.swift](../../SmartTubeIOS/Sources/SmartTubeIOS/Views/Home/HomeView.swift), [ShortsRowSection.swift](../../SmartTubeIOS/Sources/SmartTubeIOS/Views/Browse/ShortsRowSection.swift), [ShortsCardView.swift](../../SmartTubeIOS/Sources/SmartTubeIOS/Views/Browse/ShortsCardView.swift), [VideoCardView.swift](../../SmartTubeIOS/Sources/SmartTubeIOS/Views/Browse/VideoCardView.swift)

## Models

- `Video.isShort` marks a Short.
- `VideoGroup` holds `videos`, `nextPageToken` and a `layout`: `.row` (horizontal shelf) or `.grid`.
- `BrowseSection.SectionType` lists every chip. `defaultSections` are Home, Subscriptions, History,
  Playlists and Channels. `allSections` adds Recommended, Shorts, Music, Gaming, News, Live, Sports
  and Watch Later.

## API

| Method | Source | Client |
|---|---|---|
| `fetchHome`, `fetchHomeRows` | `FEwhat_to_watch` | TVHTML5 when signed in, otherwise WEB |
| `fetchSubscriptions` | `FEsubscriptions` | TVHTML5 |
| `fetchHistory` | `FEhistory` | TVHTML5 |
| `fetchShorts` | Search for `#shorts` with the short-duration filter | WEB, no token |
| `fetchNews` | Search for `news today` | WEB, no token |

`fetchMusic`, `fetchGaming`, `fetchLive` and `fetchSports` browse `FEmusic_home`, `FEgaming`,
`FElive_home` and `FEsportsau`, and fall back to a search if that fails or returns nothing.

YouTube deprecated the `FEshorts` browse ID: it returned HTTP 400 on every client, so `fetchShorts`
uses search instead. It keeps results already flagged as Shorts, plus any video of 180 seconds or
less, and marks them all `isShort`. Its continuation tokens carry a `srch:` prefix, which tells
`fetchShortsMore` to continue through search.

## Shorts detection

- `reelItemRenderer`: always a Short.
- `shortsLockupViewModel`: always a Short. WEB search returns Shorts in this form.
- `lockupViewModel`: a `reelWatchEndpoint`.
- `tileRenderer` (TVHTML5): the `TILE_STYLE_YTLR_SHORTS` style, a `reelWatchEndpoint` or a `SHORTS`
  overlay. Also the `GgIIBQ==` `ustreamerConfig` or a vertical thumbnail, unless the video is known
  to be longer than 180 seconds.
- `videoRenderer`: a `reelWatchEndpoint`, a `SHORTS` overlay, the `GgIIBQ==` `ustreamerConfig` or a
  vertical thumbnail, unless the video is known to be longer than 180 seconds. Most WEB search
  results carry none of these, which is why `fetchShorts` also uses duration.

## Where Shorts appear

`ShortsFeedPolicy.showsInHomeFeeds` is `false`, so Home and Recommended leave Shorts out. The view
models take it as an init default (`showsShorts`, `showsRecommendedShorts`), and tests can override it.

| Section | Behaviour |
|---|---|
| Home | No Shorts are fetched or shown; any in the feed are dropped |
| Recommended | No Shorts requests and no Shorts row; any in the feed are dropped |
| Shorts chip | Vertical list from `fetchShorts`, ignoring `hideShorts` |
| History | Pinned Shorts row, ignoring `hideShorts` |
| Other sections | Shorts move to a pinned row above the grid, unless `hideShorts` is on |

`AppSettings.hideShorts` is applied while rendering, not in the API layer. `ShortsRowSection` draws
the row with `ShortsCardView`; regular videos use `VideoCardView`.

## Home load flow

`HomeView` shows `homeShelves` for the `.home` section and `sectionFeed` for every other section.

`HomeViewModel.load()`:

1. Clears its state and fetches Recommended (`.home`, via `fetchHomeRows`) and Subscriptions in
   parallel. If the home feed is empty, it falls back to a search for `popular`.
2. Shows whichever section arrives first as a flat list, so content appears right away.
3. Once both have arrived, rebuilds `mergedVideos` once: one subscription video after every four
   recommended videos, without duplicates.

Pagination appends to `mergedVideos` and never reorders it. `homeRegularVideos` is `mergedVideos`
without Shorts, and that is what the Home grid shows.

`HomeViewModel` still has code to page Shorts (`homeShortsVideos`, `loadMoreShortsIfNeeded`,
`preloadMoreShorts`). It only runs with `showsShorts: true`, which the app doesn't currently use.

## Other sections

`BrowseViewModel.fetchSection` loads the selected section into `videoGroups`. `HomeView.feedContent`
then applies the filters (Shorts, live Shorts, premieres, watched videos, Subscriptions channel) and
draws any `.row` groups as shelves and everything else as a grid.

Recommended uses `fetchHome`, and Subscriptions sorts its first page newest-first. Later pages are
appended without re-sorting, so rows already on screen don't move.

`BrowseViewModel` removes duplicates by video ID, and it stops paging the Shorts chip after three
pages in a row with no new videos.
