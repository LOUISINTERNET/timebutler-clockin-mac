import SwiftUI

/// Fixed-size frame for every settings tab (FR-P1) with the keychain note below the
/// grouped form (FR-P6), in the style of Password Filler's settings.
struct SettingsTabContainer<Content: View>: View {
    static var size: CGSize {
        CGSize(width: 540, height: 440)
    }

    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
            Text("Zugangsdaten liegen im macOS-Schlüsselbund und gehen ausschließlich an app.timebutler.com.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
