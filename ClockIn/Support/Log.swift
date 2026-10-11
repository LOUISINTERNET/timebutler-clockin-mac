import os

/// Logging categories, one per subsystem area. The subsystem is the bundle identifier.
enum LogCategory: String {
    case lifecycle
    case api
    case session
    case clock
    case statusBar = "statusbar"
    case widget
    case settings
    case update
}

enum Log {
    static func logger(_ category: LogCategory) -> Logger {
        Logger(subsystem: AppIdentity.bundleIdentifier, category: category.rawValue)
    }
}
