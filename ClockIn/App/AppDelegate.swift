import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Log.logger(.lifecycle)
    private var statusItem: NSStatusItem?

    /// AppKit's default `NSApplicationDelegate.main()` only calls `NSApplicationMain`, which
    /// wires the delegate through a main nib. This app has no nib, so the delegate is set here.
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: AppIdentity.displayName)
        statusItem = item
        logger.notice("\(AppIdentity.displayName, privacy: .public) launched")
    }
}
