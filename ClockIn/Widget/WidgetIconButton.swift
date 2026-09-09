import SwiftUI

/// A round 24-point action button for the folded widget: filled SF Symbol in the action colour.
struct WidgetIconButton: View {
    let symbol: String
    let tint: Color
    let help: String
    let action: @MainActor () async -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .help(help)
    }
}
