import Foundation
import Observation

/// The small settings the app keeps in UserDefaults (design decision D16). Credentials live
/// in the keychain.
@MainActor
@Observable
final class Preferences {
    private static let widgetVisibleKey = "widgetVisible"
    private static let widgetOnAllSpacesKey = "widgetOnAllSpaces"
    private static let launchAtLoginKey = "launchAtLogin"
    private static let widgetCollapsedKey = "widgetCollapsed"
    private static let widgetAlwaysOnTopKey = "widgetAlwaysOnTop"
    private static let widgetPositionKey = "widgetPosition"

    private let defaults: UserDefaults
    private let logger = Log.logger(.settings)

    /// FR-W5: whether the widget is shown; restored at launch.
    var widgetVisible: Bool {
        didSet {
            defaults.set(widgetVisible, forKey: Self.widgetVisibleKey)
            logger.notice("widgetVisible = \(self.widgetVisible, privacy: .public)")
        }
    }

    /// FR-W4: the widget joins every Space and floats over full-screen apps.
    var widgetOnAllSpaces: Bool {
        didSet {
            defaults.set(widgetOnAllSpaces, forKey: Self.widgetOnAllSpacesKey)
            logger.notice("widgetOnAllSpaces = \(self.widgetOnAllSpaces, privacy: .public)")
        }
    }

    /// FR-W9: floating above every window, or a normal window other apps may cover.
    var widgetAlwaysOnTop: Bool {
        didSet {
            defaults.set(widgetAlwaysOnTop, forKey: Self.widgetAlwaysOnTopKey)
            logger.notice("widgetAlwaysOnTop = \(self.widgetAlwaysOnTop, privacy: .public)")
        }
    }

    /// FR-W8: the widget is folded to its one-line form.
    var widgetCollapsed: Bool {
        didSet {
            defaults.set(widgetCollapsed, forKey: Self.widgetCollapsedKey)
            logger.notice("widgetCollapsed = \(self.widgetCollapsed, privacy: .public)")
        }
    }

    /// FR-W2, FR-W10: the widget's pinned corner; nil until the widget was placed once.
    var widgetPosition: WidgetPosition? {
        didSet {
            defaults.set(widgetPosition?.propertyList, forKey: Self.widgetPositionKey)
            // Debug, not notice: a drag writes it on every step.
            logger.debug("widgetPosition = \(String(describing: self.widgetPosition), privacy: .public)")
        }
    }

    /// EC-8: what the user asked for, so a lost login item can be registered again at launch.
    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Self.launchAtLoginKey)
            logger.notice("launchAtLogin = \(self.launchAtLogin, privacy: .public)")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.widgetVisibleKey: true, Self.widgetOnAllSpacesKey: true, Self.launchAtLoginKey: false, Self.widgetCollapsedKey: false, Self.widgetAlwaysOnTopKey: true])
        widgetVisible = defaults.bool(forKey: Self.widgetVisibleKey)
        widgetOnAllSpaces = defaults.bool(forKey: Self.widgetOnAllSpacesKey)
        widgetAlwaysOnTop = defaults.bool(forKey: Self.widgetAlwaysOnTopKey)
        widgetCollapsed = defaults.bool(forKey: Self.widgetCollapsedKey)
        launchAtLogin = defaults.bool(forKey: Self.launchAtLoginKey)
        let storedPosition = defaults.object(forKey: Self.widgetPositionKey)
        widgetPosition = (storedPosition as? [String: Any]).flatMap(WidgetPosition.init(propertyList:))
        if let storedPosition, widgetPosition == nil {
            logger.error("Saved widget position \(String(describing: storedPosition), privacy: .public) is malformed, the widget goes back to the top right corner")
        }
    }
}
