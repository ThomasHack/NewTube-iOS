import Foundation
import Testing

@testable import SmartTubeCore

// MARK: - FEShortsClientRegressionTests
//
// Regression tests for task #96: the device-code OAuth token is bound to TVHTML5, and
// YouTube answers HTTP 400 when the WEB client sends it. So a WEB request must not carry
// the token, and a request that carries it must use TVHTML5.
//
// fetchShorts now searches with the WEB client and no token, because YouTube deprecated
// FEshorts. fetchShortsMore with an untagged token still uses TVHTML5.
//
// These tests intercept the outgoing URLRequest via URLProtocol and check its client
// name and Authorization header.

// MARK: - URLProtocol helper

/// Intercepts the first outgoing POST request and captures its JSON body.
/// Returns HTTP 400 so the caller's network path fails fast.
private final class BodyCapturingURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var capturedBody: Data?
    nonisolated(unsafe) static var capturedAuthorization: String?

    override class func canInit(with request: URLRequest) -> Bool {
        request.httpMethod == "POST"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // URLSession converts httpBody to httpBodyStream before handing the request
        // to URLProtocol; httpBody is always nil here.
        // Only capture the FIRST request.
        if BodyCapturingURLProtocol.capturedBody == nil {
            BodyCapturingURLProtocol.capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            if let stream = request.httpBodyStream {
                stream.open()
                var body = Data()
                let bufferSize = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer {
                    buffer.deallocate()
                    stream.close()
                }
                // Use read-until-zero rather than hasBytesAvailable; the latter
                // can return false prematurely for in-memory streams.
                while true {
                    let count = stream.read(buffer, maxLength: bufferSize)
                    if count <= 0 { break }
                    body.append(buffer, count: count)
                }
                BodyCapturingURLProtocol.capturedBody = body
            } else if let bodyData = request.httpBody {
                // Fallback: some configurations pass the body directly in httpBody.
                BodyCapturingURLProtocol.capturedBody = bodyData
            }
        }

        // Reply with a minimal HTTP 400 response so the API call fails fast.
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite("Shorts requests never send the TV token with the WEB client — Regression #96", .serialized)
struct FEShortsClientRegressionTests {

    // MARK: - Helpers

    /// Returns an `InnerTubeAPI` wired to `BodyCapturingURLProtocol` via an ephemeral
    /// `URLSession`. This avoids polluting the global URLProtocol registry.
    private func makeTestAPI(authToken: String) -> InnerTubeAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BodyCapturingURLProtocol.self]
        let session = URLSession(configuration: config)
        return InnerTubeAPI(authToken: authToken, session: session)
    }

    // MARK: - fetchShorts

    /// Verifies that fetchShorts searches with the WEB client and leaves the token out,
    /// even when signed in. Sending the TV token with the WEB client returns HTTP 400.
    @Test("fetchShorts searches with the WEB client and no token when authenticated")
    func fetchShortsSearchesWithoutTokenWhenAuthenticated() async throws {
        BodyCapturingURLProtocol.capturedBody = nil
        BodyCapturingURLProtocol.capturedAuthorization = nil
        let api = makeTestAPI(authToken: "fake-tv-oauth-token")

        // The call will throw (HTTP 400 from BodyCapturingURLProtocol), which is expected.
        _ = try? await api.fetchShorts()

        let bodyData = try #require(
            BodyCapturingURLProtocol.capturedBody,
            "URLProtocol should have captured the POST body"
        )
        let json = try #require(
            try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            "Request body must be valid JSON"
        )

        let context = json["context"] as? [String: Any]
        let clientDict = context?["client"] as? [String: Any]

        #expect(clientDict?["clientName"] as? String == "WEB")
        #expect(json["query"] as? String == "#shorts")
        #expect(BodyCapturingURLProtocol.capturedAuthorization == nil)
    }

    // MARK: - fetchShortsMore

    /// Verifies that fetchShortsMore sends `clientName: "TVHTML5"`.
    ///
    /// Continuation tokens are client-scoped: a token from a TVHTML5 FEshorts
    /// response must be submitted with TVHTML5 context to work correctly.
    @Test("fetchShortsMore sends TVHTML5 clientName")
    func fetchShortsMoreSendsTVClient() async throws {
        BodyCapturingURLProtocol.capturedBody = nil
        let api = makeTestAPI(authToken: "fake-tv-oauth-token")

        _ = try? await api.fetchShortsMore(continuationToken: "test-continuation-token-12345")

        let bodyData = try #require(
            BodyCapturingURLProtocol.capturedBody,
            "URLProtocol should have captured the POST body"
        )
        let json = try #require(
            try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            "Request body must be valid JSON"
        )

        let context = json["context"] as? [String: Any]
        let clientDict = context?["client"] as? [String: Any]

        #expect(
            clientDict?["clientName"] as? String == "TVHTML5",
            """
            fetchShortsMore must use TVHTML5 client.
            Found clientName=\(String(describing: clientDict?["clientName"]))
            """
        )
        #expect(
            json["continuation"] as? String == "test-continuation-token-12345",
            "fetchShortsMore must forward the continuation token in the body"
        )
    }
}
