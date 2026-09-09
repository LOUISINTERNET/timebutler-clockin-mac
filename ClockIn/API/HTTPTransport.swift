import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

struct HTTPResponse: Sendable, Equatable {
    let statusCode: Int
    let body: Data
}

/// Network-level failure: no HTTP response was received at all.
struct TransportError: Error, Equatable, Sendable {
    let description: String
}

/// The only way any code in the app talks to the network. Tests replace it with an
/// in-memory fake that replays fixtures.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw TransportError(description: "\(error.code.rawValue) \(error.localizedDescription)")
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError(description: "Non-HTTP response from \(request.url?.absoluteString ?? "unknown URL")")
        }
        return HTTPResponse(statusCode: httpResponse.statusCode, body: data)
    }
}
