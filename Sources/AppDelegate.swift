import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var service: NowPlayingService!
    private var store: CardStore!
    private var panelController: PanelController!
    private var preferences: PreferencesWindowController?
    private var hotKeySignature = ""
    private var configSink: AnyCancellable?
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?
    private var pinItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = CardStore()
        service = NowPlayingService()
        panelController = PanelController(service: service, store: store)
        setUpStatusItem()
        registerHotKeys()
        updateMenu()

        configSink = store.$config
            .dropFirst()
            .sink { [weak self] _ in
                self?.registerHotKeys()
                self?.updateMenu()
            }

        // Dev affordances: `--show` opens the card, `--settings` the settings window.
        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.panelController.show()
            }
        }
        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openSettings()
            }
        }

        // Dev affordance: `--send <command>` fires one media command, then quits.
        if let index = CommandLine.arguments.firstIndex(of: "--send"),
           index + 1 < CommandLine.arguments.count {
            let name = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self else { return }
                if let command = NowPlayingService.Command(rawValue: name) {
                    NSLog("Vodya: --send \(name) source=\(self.service.track.sourceBundleID)")
                    self.service.send(command)
                } else {
                    NSLog("Vodya: --send unknown command \(name)")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Hot keys

    private func registerHotKeys() {
        let behavior = store.config.behavior
        let signature = behavior.hotkey + "|" + behavior.pinHotkey
        guard signature != hotKeySignature else { return }
        hotKeySignature = signature
        HotKeyCenter.shared.unregisterAll()

        if let spec = HotKeySpec.parse(behavior.hotkey) {
            let registered = HotKeyCenter.shared.register(
                id: 1,
                keyCode: spec.keyCode,
                modifiers: spec.modifiers
            ) { [weak self] in
                self?.panelController.toggle()
            }
            NSLog(registered
                ? "Vodya: \(behavior.hotkey) hotkey registered"
                : "Vodya: could not register \(behavior.hotkey) (already taken by another app?)")
        }

        if let spec = HotKeySpec.parse(behavior.pinHotkey) {
            let registered = HotKeyCenter.shared.register(
                id: 2,
                keyCode: spec.keyCode,
                modifiers: spec.modifiers
            ) { [weak self] in
                self?.togglePin()
            }
            NSLog(registered
                ? "Vodya: \(behavior.pinHotkey) hotkey registered"
                : "Vodya: could not register \(behavior.pinHotkey)")
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Vodya")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Now Playing", action: #selector(togglePanel), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        toggleItem = toggle

        let pin = NSMenuItem(title: "Pin to Screen", action: #selector(togglePin), keyEquivalent: "")
        pin.target = self
        menu.addItem(pin)
        pinItem = pin

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        let edit = NSMenuItem(title: "Edit config.json", action: #selector(editConfig), keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)

        let reveal = NSMenuItem(title: "Reveal config in Finder", action: #selector(revealConfig), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Vodya", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    private func updateMenu() {
        let behavior = store.config.behavior
        toggleItem?.title = "Now Playing    \(HotKeySpec.label(behavior.hotkey))"
        pinItem?.title = "Pin to Screen    \(HotKeySpec.label(behavior.pinHotkey))"
        pinItem?.state = behavior.pinned ? .on : .off
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func togglePin() {
        store.update { $0.behavior.pinned.toggle() }
    }

    @objc private func openSettings() {
        if preferences == nil {
            preferences = PreferencesWindowController(store: store)
        }
        preferences?.present()
    }

    @objc private func editConfig() {
        NSWorkspace.shared.open(store.fileURL)
    }

    @objc private func revealConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
