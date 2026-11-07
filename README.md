# SmartTube

A native Swift/SwiftUI YouTube client for **Apple TV**.  
Zero ads. SponsorBlock auto-skip. DeArrow community titles. Google sign-in. Up to 8K.

[![tvOS 27+](https://img.shields.io/badge/tvOS-27%2B-black?logo=apple)](https://apps.apple.com/us/app/smart-tube-bdp/id6761388918) [![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org) [![Ko-fi](https://img.shields.io/badge/Ko--fi-support-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/milikadelic)

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/smart-tube-bdp/id6761388918)

Inspired by the original [SmartTube Android app](https://github.com/yuliskov/SmartTube).

---

## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/home.png" width="160"/></td>
    <td><img src="docs/screenshots/subscriptions.png" width="160"/></td>
    <td><img src="docs/screenshots/player.png" width="160"/></td>
    <td><img src="docs/screenshots/player-menu.png" width="160"/></td>
    <td><img src="docs/screenshots/settings.png" width="160"/></td>
  </tr>
</table>

---

## Features

### Playback
- Adaptive HLS and DASH streaming — up to 8K via AVPlayer; manual quality picker (144p → 4K)
- DASH adaptive quality switching via `AVMutableComposition` — no black frames, audio preserved on every switch
- Audio-only playback mode
- Adjustable playback speed, seek interval, and sleep timer
- Previous / next video navigation
- Now Playing metadata

### Audio & Captions
- Multi-track audio selection with a preferred-language setting (original, English, dubbed, and more)
- Caption / subtitle track selection — language choice remembered across videos

### Content & Feeds
- Home, Subscriptions, Shorts, History, Search, Playlists, Library
- Local subscriptions — follow channels without a Google account
- RSS channel feeds with background refresh and deduplication
- iCloud sync for subscriptions, watch state, queue, and RSS feeds
- Video publish date shown in search results and feed cards

### Ad & Sponsor Blocking
- Zero ads, no tracking
- SponsorBlock — auto-skip with per-category controls and skip-button toast
- DeArrow community titles and thumbnails

### Integrations
- Google OAuth sign-in (YouTube TV device-code flow)
- WatchTime reporting and Like / Dislike support
- VPN / IP-block detection with a clear, non-retrying error banner
- Comments, Stats for Nerds

### Platform
- **Apple TV** — tvOS 27+, full Siri Remote / d-pad navigation

---

## Project Structure

```
SmartTubeCore/         Swift Package — models, InnerTube API, SponsorBlock, stores
SmartTubeApp/          Xcode project — Apple TV app (views, view models, services) and its tests
SmartTube.xcworkspace/ Xcode workspace (references both above)
```

---

## Requirements

| Platform | Minimum |
|---|---|
| tvOS | 27.0 |
| Xcode | 27.0 |
| Swift | 6.4 |

---

## Getting Started

```bash
git clone https://github.com/milika/SmartTubeIOS
cd SmartTubeIOS
open SmartTube.xcworkspace
```

### Signing

The project requires an Apple Developer Team ID to build.  
Copy `SmartTubeApp/Config/Secrets.xcconfig.example` to `SmartTubeApp/Config/Secrets.xcconfig` and fill in your Team ID:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
SMARTTUBE_TV_TEAM = YOUR_TEAM_ID
```

`Secrets.xcconfig` is gitignored and will never be committed.

---

## Contributing

Pull requests are welcome. See [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md) for the checklist.  
Please ensure `Secrets.xcconfig` is **never** included in a PR.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a full version history.

---

## Support

If SmartTube is useful to you and you'd like to support its development, there's a [Ko-fi](https://ko-fi.com/milikadelic).

---

## License

[GPL-3.0](LICENSE)
