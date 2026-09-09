import Foundation

/// Client for the Timebutler REST API v2 endpoints the app uses.
struct TimebutlerAPI: Sendable {
    static let defaultBaseURL: URL = {
        guard let url = URL(string: "https://app.timebutler.com/api/v2") else {
            preconditionFailure("Base URL literal is not a valid URL")
        }
        return url
    }()

    private let transport: any HTTPTransport
    private let tokenProvider: any TokenProvider
    private let baseURL: URL
    private let logger = Log.logger(.api)

    init(transport: any HTTPTransport, tokenProvider: any TokenProvider, baseURL: URL = TimebutlerAPI.defaultBaseURL) {
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.baseURL = baseURL
    }

    /// The same server and transport, but authenticated with one fixed token. Used to check
    /// a freshly entered personal token before it replaces the stored credentials (FR-S2).
    func authenticating(with token: String) -> TimebutlerAPI {
        TimebutlerAPI(transport: transport, tokenProvider: StaticTokenProvider(token: token), baseURL: baseURL)
    }

    func status() async throws -> TimeClockStatus {
        try await send(.get, path: "time-clock/status", action: nil)
    }

    func workSummary() async throws -> WorkSummary {
        try await send(.get, path: "time-tracking/work-summary", action: nil)
    }

    func profile() async throws -> UserProfile {
        try await send(.get, path: "user/profile", action: nil)
    }

    /// start, pause, resume and cancel all answer with the new clock status.
    func perform(_ action: ClockAction) async throws -> TimeClockStatus {
        precondition(action != .stop, "Use stop(_:) for the stop endpoint")
        return try await send(.post, path: action.path, action: action)
    }

    func stop(_ request: TimeClockStopRequest) async throws -> StopResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(request)
        let response = try await exchange(.post, path: ClockAction.stop.path, body: body, action: .stop)
        if response.statusCode == 204 {
            return .discarded
        }
        return StopResult(response: try decode(TimeClockStopResponse.self, from: response))
    }

    private func send<Value: Decodable>(_ method: HTTPMethod, path: String, action: ClockAction?) async throws -> Value {
        let response = try await exchange(method, path: path, body: nil, action: action)
        return try decode(Value.self, from: response)
    }

    /// Sends the request, retries once with a recovered token after 401, and turns every
    /// non-2xx answer into an `APIError`.
    private func exchange(_ method: HTTPMethod, path: String, body: Data?, action: ClockAction?) async throws -> HTTPResponse {
        var response = try await perform(method, path: path, body: body, token: try await tokenProvider.accessToken())
        if response.statusCode == 401, let recoveredToken = try await tokenProvider.recoverFromUnauthorized() {
            logger.notice("401 for \(path, privacy: .public), retrying once with a refreshed token")
            response = try await perform(method, path: path, body: body, token: recoveredToken)
        }
        guard (200...299).contains(response.statusCode) else {
            let detail = String(decoding: response.body, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            logger.error("\(method.rawValue, privacy: .public) \(path, privacy: .public) failed with HTTP \(response.statusCode, privacy: .public): \(detail.prefix(200), privacy: .private)")
            throw APIError.http(status: response.statusCode, action: action, detail: detail)
        }
        return response
    }

    private func perform(_ method: HTTPMethod, path: String, body: Data?, token: String) async throws -> HTTPResponse {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method.rawValue
        request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let started = ContinuousClock.now
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch let error as TransportError {
            logger.error("\(method.rawValue, privacy: .public) \(path, privacy: .public) transport failure: \(error.description, privacy: .public)")
            throw APIError.transport(error.description)
        }
        let milliseconds = Int((ContinuousClock.now - started) / .milliseconds(1))
        logger.info("\(method.rawValue, privacy: .public) \(path, privacy: .public) -> HTTP \(response.statusCode, privacy: .public) in \(milliseconds, privacy: .public) ms")
        return response
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from response: HTTPResponse) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: response.body)
        } catch {
            logger.error("Unreadable \(String(describing: Value.self), privacy: .public) (\(response.body.count, privacy: .public) bytes): \(String(describing: error), privacy: .public)")
            throw APIError.unreadableResponse
        }
    }
}
