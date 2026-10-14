import Foundation

/// Path availability that the test yields by hand instead of `NWPathMonitor`.
final class FakeNetworkPathSource: NetworkPathSource {
    let continuation: AsyncStream<Bool>.Continuation
    private let paths: AsyncStream<Bool>

    init() {
        (paths, continuation) = AsyncStream.makeStream(of: Bool.self)
    }

    func pathAvailability() -> AsyncStream<Bool> {
        paths
    }
}
