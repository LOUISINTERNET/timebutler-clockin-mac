import Foundation
import Testing

/// Waits for a condition with a deadline instead of a fixed window: on a shared CI runner
/// every main-actor test competes for the main actor, so fixed windows come out too short.
@MainActor
func waitUntil(timeout: Duration = .seconds(10), _ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while await !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition not met within \(timeout)")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}
