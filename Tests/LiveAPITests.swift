import Foundation
import Testing

/// Read-only calls against the real Timebutler API with a personal token. `make test`
/// skips this suite; `make test-live` runs only it and forwards the token as
/// `TEST_RUNNER_TIMEBUTLER_API_TOKEN`, which xcodebuild passes into the test process
/// without the prefix. The token never appears in fixtures or in the repository.
struct LiveAPITests {
    private func makeAPI() throws -> TimebutlerAPI {
        let token = try #require(ProcessInfo.processInfo.environment["TIMEBUTLER_API_TOKEN"], "TIMEBUTLER_API_TOKEN is not set; run this suite through make test-live")
        return TimebutlerAPI(transport: URLSessionTransport(), tokenProvider: StaticTokenProvider(token: token))
    }

    @Test func profileStatusAndWorkSummaryDecodeFromTheRealAPI() async throws {
        let api = try makeAPI()
        let profile = try await api.profile()
        #expect(profile.email.contains("@"))
        #expect(profile.isTimeTrackingEnabled)
        let status = try await api.status()
        #expect(status.workTimeElapsedSeconds >= 0)
        let summary = try await api.workSummary()
        #expect(summary.commitmentMinutes >= 0)
    }
}
