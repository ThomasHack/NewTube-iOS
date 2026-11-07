---
status: accepted
date: 2026-11-07
deciders: maintainer
---
# 0012. One navigator; the player covers the tabs

## Context and problem statement

The player was pushed onto each tab's `NavigationStack`, so it was tab content. With
`.sidebarAdaptable`, the sidebar could appear over it. Each view also declared its own
`navigationDestination(item:)`, and `.openChannel` was a broadcast that every mounted view handled.

## Decision

`AppNavigator` owns the selected tab, one `[AppRoute]` path per tab, and the player presentation,
and views reach it through the environment. The player is one `fullScreenCover`
on the `TabView`, which is Apple's usual presentation for video on tvOS. Opening a channel from the
player closes the player and pushes the channel onto the current tab. `AppFeeds` holds page view
models above the `TabView`, which discards a tab's `@State` when another tab is selected.

## Consequences

- Good: the sidebar can't appear over the player, and Menu has a single, modal meaning there.
- Good: a navigation action reaches exactly one stack, and account changes reset them all in one place.
- Bad: leaving the player for a channel ends playback; Back returns to the page the video came from,
  not to the video.

## Alternatives considered

- **`.toolbar(.hidden, for: .tabBar)` on a pushed player**: this was the old approach, and it left
  the player inside the tab.
- **A `NavigationStack` inside the cover**: keeps the video resumable, but brings back unbounded
  Player → Channel → Player stacks.
