import Foundation
import Synchronization

/// Fans session states out to any number of `AsyncStream` subscribers. Each subscription
/// buffers only the newest state and ends when its consuming task is cancelled.
final class SessionStateBroadcaster: Sendable {
    private let subscribers = Mutex<[UUID: AsyncStream<SessionState>.Continuation]>([:])

    func subscribe() -> AsyncStream<SessionState> {
        let (stream, continuation) = AsyncStream.makeStream(of: SessionState.self, bufferingPolicy: .bufferingNewest(1))
        let identifier = UUID()
        subscribers.withLock { $0[identifier] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.remove(identifier)
        }
        return stream
    }

    /// Continuations are called outside the lock: `finish()` triggers `onTermination`
    /// synchronously, which would otherwise re-enter the mutex through `remove`.
    func publish(_ state: SessionState) {
        for continuation in currentContinuations() {
            continuation.yield(state)
        }
    }

    func finish() {
        let continuations = subscribers.withLock { subscribers in
            let values = Array(subscribers.values)
            subscribers = [:]
            return values
        }
        for continuation in continuations {
            continuation.finish()
        }
    }

    private func currentContinuations() -> [AsyncStream<SessionState>.Continuation] {
        subscribers.withLock { Array($0.values) }
    }

    private func remove(_ identifier: UUID) {
        subscribers.withLock { $0[identifier] = nil }
    }
}
