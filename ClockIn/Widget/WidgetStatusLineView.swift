import SwiftUI

/// FR-C8 and FR-C11: the red error line or the grey message below the buttons.
struct WidgetStatusLineView: View {
    let error: String?
    let message: String?

    var body: some View {
        if let error {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
