import SwiftUI

extension ClockState {
    /// FR-C2: grey, green, orange, yellow.
    var color: Color {
        switch self {
        case .idle: .gray
        case .running: .green
        case .paused: .orange
        case .waiting: .yellow
        }
    }
}
