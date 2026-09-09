import SwiftUI

/// A capsule button of the widget. Prominent buttons use a solid tint so the primary
/// action stays coloured even with "Reduce transparency" on, where tinted glass turns
/// grey; secondary buttons use neutral glass with tinted text. Built-in glass button
/// styles are avoided because the non-activating panel (D3) is never the key window and
/// they render as inactive there.
struct WidgetButton: View {
    let title: String
    var symbol: String?
    let tint: Color
    let prominent: Bool
    let action: @MainActor () async -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: run) {
            if prominent {
                paddedLabel
                    .foregroundStyle(.white)
                    .background(tint, in: .capsule)
            } else {
                paddedLabel
                    .foregroundStyle(tint)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .buttonStyle(WidgetButtonStyle())
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var paddedLabel: some View {
        label
            .font(.body.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    @ViewBuilder
    private var label: some View {
        if let symbol {
            Label(title, systemImage: symbol)
        } else {
            Text(title)
        }
    }

    private func run() {
        Task {
            await action()
        }
    }
}

private struct WidgetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
