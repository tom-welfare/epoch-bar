import AppKit
import ServiceManagement

final class StatusItemController {
    private let statusItem: NSStatusItem
    private let watcher: ClipboardWatcher
    private let menu: NSMenu
    private var currentISO: String?
    private var flashTimer: Timer?
    private lazy var settingsWindow = SettingsWindowController()
    private lazy var diagnosticsWindow = DiagnosticsWindowController()

    init(watcher: ClipboardWatcher) {
        self.watcher = watcher
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()

        buildMenu()
        configureButton()

        watcher.onChange = { [weak self] parsed in
            self?.update(parsed: parsed)
        }
    }

    private func configureButton() {
        statusItem.behavior = .removalAllowed   // user can ⌘-drag to reorder/remove
        statusItem.autosaveName = "EpochBarStatusItem"

        guard let button = statusItem.button else {
            Log.status.fault("status item button is nil — icon will not appear; menu bar may be full")
            Diagnostics.shared.recordStatusItemButton(present: false)
            return
        }
        Diagnostics.shared.recordStatusItemButton(present: true)

        if let symbol = NSImage(systemSymbolName: "clock", accessibilityDescription: "EpochBar") {
            symbol.isTemplate = true
            button.image = symbol
            button.imagePosition = .imageLeft
            button.title = ""
        } else {
            // Very-old-macOS or symbol-unavailable fallback: text glyph.
            Log.status.warning("'clock' SF Symbol unavailable; falling back to text glyph")
            button.image = nil
            button.title = "⏱"
        }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        Log.status.info("status item configured")
    }

    private func buildMenu() {
        let launchItem = NSMenuItem(
            title: "Launch at login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About EpochBar",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let diagnosticsItem = NSMenuItem(
            title: "Diagnostics…",
            action: #selector(showDiagnostics),
            keyEquivalent: ""
        )
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit EpochBar",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func update(parsed: ParsedEpoch?) {
        guard let button = statusItem.button else { return }
        if let parsed {
            let iso = EpochParser.formatISO(parsed)
            currentISO = iso
            button.title = " \(iso)"
        } else {
            currentISO = nil
            button.title = ""
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            copyCurrent()
        }
    }

    private func showMenu() {
        if let launchItem = menu.items.first {
            launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func copyCurrent() {
        guard let iso = currentISO else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(iso, forType: .string)
        watcher.markJustWrote(iso)
        flashCopied()
    }

    private func flashCopied() {
        statusItem.button?.title = " ✓ copied"
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }
            if let iso = self.currentISO {
                button.title = " \(iso)"
            } else {
                button.title = ""
            }
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("EpochBar: launch-at-login toggle failed: \(error)")
        }
    }

    @objc private func showSettings() {
        settingsWindow.showWindow()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showDiagnostics() {
        diagnosticsWindow.showWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
