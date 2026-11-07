import Foundation
import Testing

@testable import SmartTube
@testable import SmartTubeCore

private final class ChannelStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var capturedHeaders: [[String: String]] = []

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedHeaders.append(request.allHTTPHeaderFields ?? [:])
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// AuthService writes to ActiveChannel.shared, so these run serially and reset it afterwards.
@MainActor
@Suite("Brand Account — AuthService channel switch and sign-out", .serialized)
struct BrandAccountAuthServiceTests {

    private final class NotificationCounter: @unchecked Sendable {
        var count = 0
    }

    private let primary = YouTubeChannel(name: "Primary User", avatarURL: nil, pageId: nil)
    private let brand = YouTubeChannel(name: "Brand Channel", avatarURL: nil, pageId: "100000000000000000001")

    /// Private, so a channel switch doesn't reload the feed view models of parallel tests.
    private let center = NotificationCenter()

    private func countChannelChanges(during action: () -> Void) -> Int {
        let counter = NotificationCounter()
        let token = center.addObserver(
            forName: .activeChannelDidChange, object: nil, queue: nil
        ) { _ in counter.count += 1 }
        action()
        center.removeObserver(token)
        return counter.count
    }

    // deve disparar activeChannelDidChange ao trocar para um Brand Account diferente do ativo
    @Test("should post activeChannelDidChange when switching to a different Brand Account")
    func postsChangeOnSwitch() {
        let auth = AuthService(notificationCenter: center)
        auth.applyChannels([primary, brand])
        defer { auth.resetChannels() }

        let changes = countChannelChanges { auth.selectChannel(brand) }

        #expect(changes == 1)
        #expect(auth.activePageId == brand.pageId)
    }

    // não deve disparar activeChannelDidChange ao selecionar o canal que já está ativo
    @Test("should not post activeChannelDidChange when selecting the already active channel")
    func skipsChangeForActiveChannel() {
        let auth = AuthService(notificationCenter: center)
        auth.applyChannels([primary, brand])
        auth.selectChannel(brand)
        defer { auth.resetChannels() }

        let changes = countChannelChanges { auth.selectChannel(brand) }

        #expect(changes == 0)
    }

    // deve limpar o canal selecionado no logout e enviar a próxima requisição sem X-Goog-Pageid
    @Test("should clear the selected channel on sign-out and send the next request without X-Goog-Pageid")
    func signOutClearsSelectedChannel() async {
        let auth = AuthService(notificationCenter: center)
        auth.applyChannels([primary, brand])
        auth.selectChannel(brand)

        auth.signOut()

        #expect(auth.activePageId == nil)
        #expect(auth.channels.isEmpty)
        #expect(ActiveChannel.shared.pageId == nil)

        ChannelStubURLProtocol.capturedHeaders = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ChannelStubURLProtocol.self]
        let session = URLSession(configuration: config)
        let api = InnerTubeAPI(authToken: "fake-token", session: session, activeChannel: .shared)
        _ = try? await api.fetchSubscriptions()

        #expect(ChannelStubURLProtocol.capturedHeaders.first?["X-Goog-Pageid"] == nil)
    }
}
