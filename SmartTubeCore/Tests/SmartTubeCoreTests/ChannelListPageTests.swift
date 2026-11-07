import Foundation
import Testing

@testable import SmartTubeCore

@Suite("FEchannels page parsing")
struct ChannelListPageTests {
    private func channelRenderer(_ id: String, _ title: String) -> [String: Any] {
        [
            "channelRenderer": [
                "channelId": id,
                "title": ["simpleText": title],
                "thumbnail": ["thumbnails": [["url": "//yt3.test/small"], ["url": "//yt3.test/\(id)"]]],
            ]
        ]
    }

    @Test func readsChannelsAndTheNextPageToken() async {
        let json: [String: Any] = [
            "contents": [
                "items": [
                    channelRenderer("UCa", "Alpha"),
                    channelRenderer("UCb", "Beta"),
                    ["continuationItemRenderer": ["continuationEndpoint": ["continuationCommand": ["token": "next"]]]],
                ]
            ]
        ]
        let page = await InnerTubeAPI().parseChannelListPage(from: json)
        #expect(page.channels.map(\.id) == ["UCa", "UCb"])
        #expect(page.channels.first?.title == "Alpha")
        #expect(page.channels.first?.isSubscribed == true)
        #expect(page.nextToken == "next")
    }

    @Test func avatarURLsGetAScheme() async {
        let page = await InnerTubeAPI().parseChannelListPage(from: ["items": [channelRenderer("UCa", "Alpha")]])
        #expect(page.channels.first?.thumbnailURL?.absoluteString == "https://yt3.test/UCa")
    }

    @Test func theLastPageHasNoToken() async {
        let page = await InnerTubeAPI().parseChannelListPage(from: ["items": [channelRenderer("UCa", "Alpha")]])
        #expect(page.nextToken == nil)
    }

    @Test func readsChannelTilesButNotVideoTiles() async {
        let channelTile: [String: Any] = [
            "tileRenderer": [
                "contentType": "TILE_CONTENT_TYPE_CHANNEL",
                "onSelectCommand": ["browseEndpoint": ["browseId": "UCtile"]],
                "metadata": ["tileMetadataRenderer": ["title": ["simpleText": "A Tile"]]],
            ]
        ]
        let videoTile: [String: Any] = [
            "tileRenderer": ["contentType": "TILE_CONTENT_TYPE_VIDEO"]
        ]
        let page = await InnerTubeAPI().parseChannelListPage(from: ["items": [channelTile, videoTile]])
        #expect(page.channels.map(\.title) == ["A Tile"])
    }
}
