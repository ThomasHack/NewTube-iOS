import Foundation
import Testing

@testable import SmartTubeIOSCore

// MARK: - TileRendererSetVideoIdTests (#157)
//
// The Home page's Watch Later section (BrowseViewModel's `.watchLater` case) fetches an
// authenticated playlist via the TV client, whose videos arrive as `tileRenderer` — a
// different shape from WEB's `playlistVideoRenderer` (see MembersOnlyPlaylistVideoRendererTests
// for that side). `parsePlaylistVideoRenderer` already populated `Video.setVideoId` from a
// top-level `setVideoId` field; `parseTileRenderer` didn't populate it at all, so removing a
// video from an authenticated Watch Later fetch always hit VideoCardView's "Missing playlist
// entry information" error. This tests that `parseTileRenderer` now extracts the equivalent
// token from `watchEndpoint.playlistSetVideoId`.

private func makeTileRendererResponse(_ tile: [String: Any]) -> [String: Any] {
    [
        "contents": [
            "sectionListRenderer": [
                "contents": [
                    [
                        "itemSectionRenderer": [
                            "contents": [["tileRenderer": tile]]
                        ]
                    ]
                ]
            ]
        ]
    ]
}

@Suite("parseTileRenderer setVideoId extraction (#157)")
struct TileRendererSetVideoIdTests {

    @Test("extracts setVideoId from watchEndpoint.playlistSetVideoId")
    func extractsFromWatchEndpoint() async throws {
        let tile: [String: Any] = [
            "contentType": "TILE_CONTENT_TYPE_VIDEO",
            "onSelectCommand": [
                "watchEndpoint": [
                    "videoId": "tilevidid",
                    "playlistId": "WL",
                    "playlistSetVideoId": "TOKEN123",
                ]
            ],
            "metadata": [
                "tileMetadataRenderer": ["title": ["simpleText": "Test Video"]]
            ],
        ]
        let response = makeTileRendererResponse(tile)
        let api = InnerTubeAPI()
        let group = try await api.parseVideoGroupForTesting(response, title: nil)
        let video = try #require(group.videos.first)
        #expect(video.setVideoId == "TOKEN123")
    }

    @Test("extracts setVideoId from reelWatchEndpoint.playlistSetVideoId for Shorts tiles")
    func extractsFromReelWatchEndpoint() async throws {
        let tile: [String: Any] = [
            "contentType": "TILE_CONTENT_TYPE_REEL",
            "onSelectCommand": [
                "reelWatchEndpoint": [
                    "videoId": "reelvidid",
                    "playlistSetVideoId": "TOKEN456",
                ]
            ],
            "metadata": [
                "tileMetadataRenderer": ["title": ["simpleText": "Test Short"]]
            ],
        ]
        let response = makeTileRendererResponse(tile)
        let api = InnerTubeAPI()
        let group = try await api.parseVideoGroupForTesting(response, title: nil)
        let video = try #require(group.videos.first)
        #expect(video.setVideoId == "TOKEN456")
    }

    @Test("nil when the watch endpoint has no playlistSetVideoId (regular feeds, not a playlist)")
    func nilWhenNoPlaylistContext() async throws {
        let tile: [String: Any] = [
            "contentType": "TILE_CONTENT_TYPE_VIDEO",
            "onSelectCommand": ["watchEndpoint": ["videoId": "tilevidid"]],
            "metadata": [
                "tileMetadataRenderer": ["title": ["simpleText": "Test Video"]]
            ],
        ]
        let response = makeTileRendererResponse(tile)
        let api = InnerTubeAPI()
        let group = try await api.parseVideoGroupForTesting(response, title: nil)
        let video = try #require(group.videos.first)
        #expect(video.setVideoId == nil)
    }

    @Test("falls back to a menu item's playlistEditEndpoint setVideoId")
    func extractsFromMenuPlaylistEditEndpoint() async throws {
        let tile: [String: Any] = [
            "contentType": "TILE_CONTENT_TYPE_VIDEO",
            "onSelectCommand": ["watchEndpoint": ["videoId": "tilevidid", "playlistId": "WL"]],
            "metadata": [
                "tileMetadataRenderer": ["title": ["simpleText": "Test Video"]]
            ],
            "menu": [
                "menuRenderer": [
                    "items": [
                        [
                            "menuServiceItemRenderer": [
                                "serviceEndpoint": [
                                    "playlistEditEndpoint": [
                                        "playlistId": "WL",
                                        "actions": [["action": "ACTION_REMOVE_VIDEO", "setVideoId": "MENUTOKEN"]],
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
        ]
        let response = makeTileRendererResponse(tile)
        let api = InnerTubeAPI()
        let group = try await api.parseVideoGroupForTesting(response, title: nil)
        let video = try #require(group.videos.first)
        #expect(video.setVideoId == "MENUTOKEN")
    }
}
