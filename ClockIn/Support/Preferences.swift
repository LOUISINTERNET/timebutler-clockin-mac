import Foundation
import Observation

/// The two flags the app keeps in UserDefaults (design decision D16). Credentials live in
/// the keychain, the widget position in the window's frame autosave.
@MainActor
@Observable
final class Preferences {
    private static let widgetVisibleKey = "widgetVisible"
    private static let widgetOnAllSpacesKey = "widgetOnAllSpaces"
    private static let launchAtLoginKey = "launchAtLogin"

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

    /// EC-8: what the user asked for, so a lost login item can be registered again at launch.
    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Self.launchAtLoginKey)
            logger.notice("launchAtLogin = \(self.launchAtLogin, privacy: .public)")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.widgetVisibleKey: true, Self.widgetOnAllSpacesKey: true, Self.launchAtLoginKey: false])
        widgetVisible = defaults.bool(forKey: Self.widgetVisibleKey)
        widgetOnAllSpaces = defaults.bool(forKey: Self.widgetOnAllSpacesKey)
        launchAtLogin = defaults.bool(forKey: Self.launchAtLoginKey)
    }
}
