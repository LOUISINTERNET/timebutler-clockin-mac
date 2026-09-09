import CoreGraphics
import Foundation

/// Which face the widget shows (FR-W8): decided in one place so it can be tested.
enum WidgetLayout: Equatable {
    /// "Nicht angemeldet." or "Sitzung abgelaufen." with the settings button.
    case signedOut
    /// The break-regulation card; always unfolded because it needs its buttons.
    case breakRegulation
    /// The full clock face.
    case face
    /// Folded: one line with the running time.
    case line
    /// Folded while stopped: a small square with just the Start button.
    case square

    /// Content height shared by the folded line and the square, so folding never changes it.
    static let foldedContentHeight: CGFloat = 36

    static func resolve(session: SessionState, collapsed: Bool, status: TimeClockStatus?, hasPendingBreakRegulation: Bool, lastError: String?) -> WidgetLayout {
        guard session.isActive else {
            return .signedOut
        }
        if hasPendingBreakRegulation {
            return .breakRegulation
        }
        guard collapsed else {
            return .face
        }
        if let status, status.status == .idle, status.canStart, lastError == nil {
            return .square
        }
        return .line
    }
}
