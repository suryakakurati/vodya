import AppKit
import Combine
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    private static let originKey = "vodya.panelOrigin"

    private let service: NowPlayingService
    private let store: CardStore
    private let panel: FloatingPanel
    private let hosting: NSHostingView<ContentView>
    private var keyMonitor: Any?
    private var shownAt = Date.distantPast
    private var cancellable: AnyCancellable?
    private var wasPinned = false

    init(service: NowPlayingService, store: CardStore) {
        self.service = service
        self.store = store

        let size = store.metrics.size

        hosting = NSHostingView(rootView: ContentView(service: service, store: store))
        panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        configure(with: size)

        cancellable = store.$config
            .dropFirst()
            .sink { [weak self] _ in self?.applyConfig() }

        DispatchQueue.main.async { [weak self] in self?.applyConfig() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard !panel.isVisible else { return }
        NSLog("Vodya: show() — pinned=\(store.config.behavior.pinned)")
        let config = store.config
        let size = store.metrics.size
        if panel.frame.size != size {
            var frame = panel.frame
            frame.size = size
            hosting.frame = NSRect(origin: .zero, size: size)
            panel.setFrame(frame, display: false)
        }

        service.startPolling(interval: config.behavior.pollInterval)
        position()
        panel.alphaValue = 0
        shownAt = Date()
        panel.level = config.behavior.pinned ? .statusBar : .floating

        // A pinned card must never pull focus away from what you're doing.
        if !config.behavior.pinned {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.orderFrontRegardless()
        if !config.behavior.pinned {
            panel.makeKey()
        }
        installKeyMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSLog("Vodya: hide()")
        service.stopPolling()
        removeKeyMonitor()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
    }

    private func configure(with size: NSSize) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting
        panel.setContentSize(size)
    }

    private func applyConfig() {
        let config = store.config
        let size = store.metrics.size

        if panel.frame.size != size {
            var frame = panel.frame
            frame.size = size
            hosting.frame = NSRect(origin: .zero, size: size)
            panel.setFrame(frame, display: panel.isVisible)
            clampToScreen()
        }

        panel.level = config.behavior.pinned ? .statusBar : .floating

        if panel.isVisible {
            service.startPolling(interval: config.behavior.pollInterval)
        }

        if config.behavior.pinned && !wasPinned {
            show()
        }
        wasPinned = config.behavior.pinned
    }

    // MARK: - Placement

    private func position() {
        let size = panel.frame.size
        if let saved = UserDefaults.standard.string(forKey: Self.originKey) {
            let parts = saved.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                let origin = NSPoint(x: parts[0], y: parts[1])
                let frame = NSRect(origin: origin, size: size)
                if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                    panel.setFrameOrigin(origin)
                    return
                }
            }
        }

        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.maxY - size.height - 14
            )
        )
    }

    private func clampToScreen() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.origin.x = min(max(frame.origin.x, visible.minX), max(visible.minX, visible.maxX - frame.width))
        frame.origin.y = min(max(frame.origin.y, visible.minY), max(visible.minY, visible.maxY - frame.height))
        panel.setFrameOrigin(frame.origin)
    }

    func windowDidMove(_ notification: Notification) {
        let origin = panel.frame.origin
        UserDefaults.standard.set("\(origin.x),\(origin.y)", forKey: Self.originKey)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !store.config.behavior.pinned, store.config.behavior.closeOnClickOutside else { return }
        // Ignore the transient resign that happens while the panel is being shown.
        guard Date().timeIntervalSince(shownAt) > 0.25 else { return }
        hide()
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            switch event.keyCode {
            case 53: // escape
                self.hide()
                return nil
            case 49: // space
                self.service.send(.togglePlayPause)
                return nil
            case 123: // left arrow
                self.service.send(.backward15)
                return nil
            case 124: // right arrow
                self.service.send(.forward15)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
