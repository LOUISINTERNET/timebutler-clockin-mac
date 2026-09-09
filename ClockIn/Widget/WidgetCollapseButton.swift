import SwiftUI

/// The chevron that folds the widget to one line or opens it again (FR-W8).
struct WidgetCollapseButton: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Button {
            preferences.widgetCollapsed.toggle()
        } label: {
            Image(systemName: preferences.widgetCollapsed ? "chevron.down" : "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(preferences.widgetCollapsed ? "Widget ausklappen" : "Widget einklappen")
    }
}
