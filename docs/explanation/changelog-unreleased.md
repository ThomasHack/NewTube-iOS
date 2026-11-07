> status: unverified — moved from private repo agent-notes, not re-audited (2026-09-11)

# Changelog: [2.6] – 2026-05-14 (current release section)

- Safari Web Extension (intercepts YouTube URLs → opens in NewTube)
- Auto quality caps at display native resolution (displayMaxVideoHeight())
- Fix DASH manual quality switching broken (AndroidVR client + playerInfo.formats URL resolution)
- Fix DASH quality switch silently rebuilding at wrong resolution (height guard in reloadDASHItem)
- Fix quality picker showing wrong heights for DASH videos (height-from-label fallback)
- Fix AndroidVR LOGIN_REQUIRED bot detection (X-Goog-Visitor-Id + shared session)
- Fix crash on age-restricted/region-locked videos
- Fix audio-only mode stalling on start
- Fix mini player X button restoring fullscreen
- Fix audio track selection lost after fallback recovery
- Fix more menu overflow in landscape
- Fix "Hide Shorts" not filtering in Search/Library/Channel views
