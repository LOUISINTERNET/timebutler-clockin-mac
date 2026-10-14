import AppKit

/// The menu bar item: symbol and running time; left and right click open the menu
/// (FR-M1 to FR-M4).
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let store: ClockStore
    /// Held here because `NSMenu.delegate` is weak.
    private let menu: StatusBarMenu
    private let logger = Log.logger(.statusBar)
    private var timer: Timer?
    private var presentation: StatusBarPresentation?

    init(store: ClockStore, menu: StatusBarMenu) {
        self.store = store
        self.menu = menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        let statusMenu = NSMenu()
        statusMenu.delegate = menu
        statusItem.menu = statusMenu
        update()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        logger.notice("Status item created")
    }

    /// FR-M2: the title changes at every full minute; AppKit is only touched on a change.
    func update() {
        let next = StatusBarPresentation.make(session: store.session, status: store.status, fetchedAt: store.fetchedAt, now: Date())
        guard next != presentation else {
            return
        }
        presentation = next
        statusItem.button?.image = NSImage(systemSymbolName: next.symbolName, accessibilityDescription: AppIdentity.displayName)
        statusItem.button?.title = next.title
    }
}
