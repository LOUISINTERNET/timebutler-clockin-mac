import AppKit

/// The menu bar item: symbol and running time, left click raises the widget, right click
/// opens the menu (FR-M1 to FR-M4).
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let store: ClockStore
    private let widget: WidgetPanelController
    private let menu: StatusBarMenu
    private let logger = Log.logger(.statusBar)
    private var timer: Timer?
    private var presentation: StatusBarPresentation?

    init(store: ClockStore, widget: WidgetPanelController, menu: StatusBarMenu) {
        self.store = store
        self.widget = widget
        self.menu = menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
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

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            widget.show()
            widget.raise()
        }
    }

    /// Attaching the menu only for the click keeps the left click free for the widget.
    private func showMenu() {
        statusItem.menu = menu.build()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
