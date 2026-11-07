> status: unverified — moved from private repo agent-notes, not re-audited (2026-09-11)

# Task #89: Fix video wrongly detected as short

## Issue
Video `vkUokV3Xwp8` (regular YouTube video) is incorrectly classified as a Short.

## Root Cause Analysis

### Short Detection Logic by Renderer Type

**parseVideoRenderer (WEB API)** — Lines 628-640 in InnerTubeAPI+VideoRenderers.swift
- Primary signal: `reelWatchEndpoint` in `navigationEndpoint` → isShort = true
- Secondary signal: `thumbnailOverlayTimeStatusRenderer.style == "SHORTS"` → isShort = true
- **Problem**: The "SHORTS" overlay style is checked WITHOUT duration validation

**parseTileRenderer (TVHTML5)** — Lines 365-411 in InnerTubeAPI+VideoRenderers.swift
- TILE_STYLE_YTLR_SHORTS style
- reelWatchEndpoint in onSelectCommand or navigationEndpoint
- SHORTS overlay style
- ustreamerConfig == "GgIIBQ==" WITH duration guard: `duration.map { $0 <= 180 } ?? true`
- Portrait thumbnail (height > width)

### The Vulnerability

In parseVideoRenderer, duration is calculated BEFORE isShort (line 616), but:
```swift
let duration = lengthText.flatMap { parseDuration($0) }

let isShort: Bool = {
    if let nav = r["navigationEndpoint"] as? [String: Any], nav["reelWatchEndpoint"] != nil {
        return true
    }
    // NO DURATION CHECK HERE — overlayStyle signal is trusted unconditionally
    return (r["thumbnailOverlays"] as? [[String: Any]])?.contains {
        ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["style"] as? String == "SHORTS"
    } ?? false
}()
```

A regular video appearing in subscriptions feed or other contexts with `thumbnailOverlayTimeStatusRenderer.style == "SHORTS"` will be misclassified, even if its duration is > 180s.

## Concrete Fix Plan

### 1. Add Duration Guard to parseVideoRenderer (line 628-640)
Validate the overlay style signal with a max-duration check, matching the tileRenderer logic:

```swift
let isShort: Bool = {
    if let nav = r["navigationEndpoint"] as? [String: Any], nav["reelWatchEndpoint"] != nil {
        return true
    }
    // Secondary: SHORTS overlay style guarded by max-duration (180s)
    // Videos longer than Shorts max-length must not be tagged as shorts.
    let hasShortOverlay = (r["thumbnailOverlays"] as? [[String: Any]])?.contains {
        ($0["thumbnailOverlayTimeStatusRenderer"] as? [String: Any])?["style"] as? String == "SHORTS"
    } ?? false
    // Guard: if duration is known and > 180s, it cannot be a short
    if hasShortOverlay && duration.map { $0 <= 180 } ?? true {
        return true
    }
    return false
}()
```

### 2. Add Regression Tests
Create a test case in SmartTubeCoreTests.swift that:
- Builds a videoRenderer with overlay style == "SHORTS" but duration > 180s
- Confirms it's tagged isShort = false
- Tests the boundary case: exactly 180s should be isShort = true

### 3. Add Logging
Update the debug logging (line 641) to include duration:
```swift
if isShort {
    let signal = ((r["navigationEndpoint"] as? [String: Any])?["reelWatchEndpoint"] != nil) ? "reelWatchEndpoint" : "overlayStyle"
    tubeLog.debug("videoRenderer isShort=true id=\(videoId, privacy: .public) signal=\(signal) duration=\(Int(duration ?? -1))")
}
```

## Files to Modify
1. [InnerTubeAPI+VideoRenderers.swift](../../SmartTubeCore/Sources/SmartTubeCore/InnerTubeAPI+VideoRenderers.swift) — parseVideoRenderer function
2. [SmartTubeCoreTests.swift](../../SmartTubeCore/Tests/SmartTubeCoreTests/SmartTubeCoreTests.swift) — add regression test case

## Why This Works
- Shorts have a hard max-length of 180s (YouTube's official limit)
- Overlay style is a weak signal that can leak to regular videos in certain feeds
- Duration validation acts as a firewall against false positives
- Matches existing pattern in parseTileRenderer for ustreamerConfig signal
