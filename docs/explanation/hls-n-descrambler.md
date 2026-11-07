> status: unverified — moved from private repo agent-notes, not re-audited (2026-09-11)

# HLS n-parameter descrambling — SOLVED

## testAutoQualityAbove360p — PASSING (16s)
- Video: `Wu8xNx4njoM`, minimumHeight=720, plays at 1080p
- WebSafari client (WEB nameID=1 + macOS Safari UA) → `hlsManifestUrl` with 6 HLS variants → descramble n → AVPlayer plays 1080p

## YouTubeNDescrambler.swift
- Location: `NewTubeApp/NewTube/Services/`
- Simulator-only (`#if targetEnvironment(simulator)`)
- Downloads player.js (version from youtube.com homepage), cached to `/tmp/yt_player_VERSION.js`
- Finds yt-dlp EJS solver scripts via `posix_spawn`+`/usr/bin/find`
- Runs Deno solver script from temp file via `posix_spawn`, reads stdout pipe
- `posix_spawn_file_actions_adddup2` / `Darwin.pipe()` / `Darwin.read/close/waitpid` all available in iOS SDK

## Critical pitfalls
- `Process` / `popen` / `pclose` — NOT in iOS SDK, even in simulator target; use `posix_spawn`
- `NSJSONSerialization.data(withJSONObject: String)` — throws NSException (NOT Swift Error), crashes app; use `JSONEncoder().encode(value: String)` instead
- n is in URL path: `/n/SCRAMBLED/` → replace with `/n/DESCRAMBLED/`
- AVPlayer gets 403 on segments if n is scrambled; 200 if descrambled
