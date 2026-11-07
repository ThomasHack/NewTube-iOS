---
status: accepted
date: 2026-11-07
deciders: maintainer
---
# 0014. Playback uses the system player

## Context and problem statement

The player was a bare `AVPlayerLayer` with hand-written controls, focus handling and pickers, about
2,600 lines. It didn't behave like other tvOS apps, and its manual focus code caused recurring bugs.
All playback already ran through one `AVPlayer`, so nothing required a custom UI.

## Decision

Show `PlaybackViewModel.player` in `AVPlayerViewController`. App features use its extension points:
transport bar menus (quality, speed, captions, sleep timer and more), `contextualActions` (SponsorBlock's
skip button), `navigationMarkerGroups` (chapters), `interstitialTimeRanges` (SponsorBlock segments),
`customInfoViewControllers` (comments) and `contentOverlayView` (captions, stats, audio-only artwork).

## Consequences

- Good: standard tvOS playback UI and focus behavior, and far less code.
- Bad: less control over the look. SponsorBlock segments aren't colored by category.
- Bad: seek length and control hiding are the system's, so those settings are gone.
- Bad: hold-for-2x speed and tappable timestamps in descriptions are gone.

## Alternatives considered

- **Keep the custom player**: full control over the look, but it keeps the focus bugs and the code.
