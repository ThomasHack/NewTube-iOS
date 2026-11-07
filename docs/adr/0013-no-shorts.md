---
status: accepted
date: 2026-11-07
deciders: maintainer
---
# 0013. The app has no Shorts

## Context and problem statement

Shorts had their own player, card and row views, API calls, a section type and two settings, even
though Apple TV's Home feed already left them out. The maintainer doesn't want Shorts in the app.

## Decision

Remove every Shorts feature. Keep `Video.isShort` and the parsing that sets it, because YouTube mixes
Shorts into normal responses: feeds, search, playlists, history, channel pages and autoplay filter on
it. A direct link to a Short still plays in the normal player.

## Consequences

- Good: much less code, and no setting to reason about.
- Bad: History no longer lists Shorts the user watched elsewhere.
- Bad: a page holding only Shorts looks empty, so feeds keep fetching until a page adds a visible video.

## Alternatives considered

- **Keep "Hide Shorts" on by default**: leaves the whole feature to maintain for an option nobody wants.
