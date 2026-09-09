import Foundation
import Testing

struct FixtureTransportError: Error {
    let message: String
}

/// In-memory HTTP fake: replays queued replies and records every request. Replies are
/// either one global queue (in call order) or per-endpoint queues keyed by path suffix,
/// which is what tests need when the code under test calls endpoints in parallel.
actor FixtureTransport: HTTPTransport {
    struct RecordedRequest: Equatable, Sendable {
        let method: String
        let url: URL
        let headers: [String: String]
        let body: Data?

        var bodyText: String {
            String(decoding: body ?? Data(), as: UTF8.self)
        }
    }

    enum Reply: Sendable {
        case fixture(Int, String)
        case raw(Int, Data)
        case failure(TransportError)
    }

    private var queue: [Reply]
    private var routes: [String: [Reply]]
    private(set) var requests: [RecordedRequest] = []
    private var holdNextSend = false
    private var heldSend: CheckedContinuation<Void, Never>?

    init(_ replies: [Reply] = [], routes: [String: [Reply]] = [:]) {
        queue = replies
        self.routes = routes
    }

    /// Appends replies to the queue of one endpoint.
    func route(_ pathSuffix: String, _ replies: [Reply]) {
        routes[pathSuffix, default: []].append(contentsOf: replies)
    }

    /// The next `send` records its request and then waits until `releaseHeldReply()` is
    /// called, so a test can run other calls while that request is in flight.
    func holdNextReply() {
        holdNextSend = true
    }

    func releaseHeldReply() {
        heldSend?.resume()
        heldSend = nil
    }

    /// Yields until at least `count` requests have been recorded; records a failure instead
    /// of hanging when they never arrive.
    func waitForRequests(count: Int) async {
        for _ in 0..<100_000 where requests.count < count {
            await Task.yield()
        }
        if requests.count < count {
            Issue.record("Timed out waiting for \(count) requests, got \(requests.count)")
        }
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        guard let url = request.url, let method = request.httpMethod else {
            throw FixtureTransportError(message: "Request without URL or method")
        }
        requests.append(RecordedRequest(method: method, url: url, headers: request.allHTTPHeaderFields ?? [:], body: request.httpBody))
        if holdNextSend {
            holdNextSend = false
            await withCheckedContinuation { heldSend = $0 }
        }
        switch try nextReply(for: url.path(), method: method) {
        case .fixture(let status, let name):
            return HTTPResponse(statusCode: status, body: try Fixture.data(name))
        case .raw(let status, let data):
            return HTTPResponse(statusCode: status, body: data)
        case .failure(let error):
            throw error
        }
    }

    func requestCount(pathSuffix: String) -> Int {
        requests.filter { $0.url.path().hasSuffix(pathSuffix) }.count
    }

    private func nextReply(for path: String, method: String) throws -> Reply {
        for (suffix, replies) in routes where path.hasSuffix(suffix) && !replies.isEmpty {
            var remaining = replies
            let reply = remaining.removeFirst()
            routes[suffix] = remaining
            return reply
        }
        guard !queue.isEmpty else {
            throw FixtureTransportError(message: "No reply queued for \(method) \(path)")
        }
        return queue.removeFirst()
    }
}

actor FakeTokenProvider: TokenProvider {
    private let token: String
    private let recoveredToken: String?
    private(set) var recoverCalls = 0

    init(token: String, recoveredToken: String? = nil) {
        self.token = token
        self.recoveredToken = recoveredToken
    }

    func accessToken() async throws -> String {
        token
    }

    func recoverFromUnauthorized() async throws -> String? {
        recoverCalls += 1
        return recoveredToken
    }
}
