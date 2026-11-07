---
status: accepted
date: 2026-11-07
deciders: maintainer
---
# 0010. tvOS is the only platform

## Context and problem statement

This fork targeted iPhone, iPad, Mac and Apple TV from one codebase. That meant hundreds of
platform conditionals, a second player stack (the WebKit-based TOS and Shorts embed players, which
can't exist on tvOS), and extension targets that a TV app has no use for. The maintainer only
develops for Apple TV, so the other platforms cost complexity and no longer give anything back.

## Decision

SmartTube builds for tvOS only. The iOS/Mac app, widget, Share and Safari extension targets are
gone, along with all code that was never compiled for tvOS. `Package.swift` declares only tvOS, and
source files no longer use platform conditionals. `AVPlayer` is the only playback path.

The package and folder names (`SmartTubeIOS`, `SmartTubeIOSCore`) stay for now, to keep this change
reviewable; ADR-0011 has since renamed them. The InnerTube `iOS` client profile also stays: it identifies an API client, not a
platform this app runs on.

## Consequences
- Good: one platform, one player, and much less code to reason about.
- Good: this supersedes ADR-0006, ADR-0007 and ADR-0008, which only applied to the removed players.
- Bad: package tests need the tvOS simulator, because `swift test` builds for the host Mac.
- Bad: bringing another platform back means restoring it from git history.

## Alternatives considered
- Keep the code but stop building it: unused code would keep costing attention and rot silently.
