import SwiftUI

/// FR-W8: the folded widget while the clock is stopped, a small tile with the Start button
/// and the chevron that unfolds it. Same 48-point height as the folded line.
struct WidgetSquareView: View {
    let store: ClockStore
    @Bindable var preferences: Preferences

    var body: some View {
        HStack(spacing: 4) {
            WidgetIconButton(symbol: "play.circle.fill", tint: .green, help: "Start") { await store.perform(.start) }
                .disabled(store.isBusy)
            WidgetCollapseButton(preferences: preferences)
        }
        .frame(height: WidgetLayout.foldedContentHeight)
    }
}
