import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(store: CardStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vodya Settings"
        window.isReleasedWhenClosed = false
        window.center()

        let hosting = NSHostingView(rootView: PreferencesView(store: store))
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
