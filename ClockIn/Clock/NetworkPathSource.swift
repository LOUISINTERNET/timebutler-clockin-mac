import Foundation
import Network

/// Reports whether the Mac has a usable network path.
protocol NetworkPathSource: Sendable {
    /// `true` while a path is satisfied, `false` otherwise. The first value is the path at
    /// the time of the call; the stream ends when the consuming task is cancelled.
    func pathAvailability() -> AsyncStream<Bool>
}

struct SystemNetworkPathSource: NetworkPathSource {
    func pathAvailability() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue(label: "app.clockin.network-path"))
        }
    }
}
