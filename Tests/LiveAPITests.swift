import Foundation
import Testing

private let liveToken = ProcessInfo.processInfo.environment["TIMEBUTLER_API_TOKEN"]

/// Read-only calls against the real Timebutler API with a personal token. The suite
/// disables itself without a token, so a plain test run stays green; `make test-live`
/// forwards the token as `TEST_RUNNER_TIMEBUTLER_API_TOKEN` (xcodebuild strips the prefix)
/// and then checks in the result bundle that the test really ran instead of being skipped.
/// The token never appears in fixtures or in the repository.
@Suite(.enabled(if: liveToken != nil, "TIMEBUTLER_API_TOKEN is not set; run make test-live"))
struct LiveAPITests {
    private func makeAPI() throws -> TimebutlerAPI {
        let token = try #require(liveToken)
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
