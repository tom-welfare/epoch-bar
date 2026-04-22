import AppKit
import ServiceManagement

final class StatusItemController {
    private let statusItem: NSStatusItem
    private let watcher: ClipboardWatcher
    private let menu: NSMenu
    private var currentISO: String?
    private var flashTimer: Timer?

    private let idleTitle = "⏱"

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
        guard let button = statusItem.button else { return }
        button.title = idleTitle
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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

        let aboutItem = NSMenuItem(
            title: "About EpochBar",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

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
            button.title = "\(idleTitle) \(iso)"
        } else {
            currentISO = nil
            button.title = idleTitle
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
        statusItem.button?.title = "\(idleTitle) ✓ copied"
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }
            if let iso = self.currentISO {
                button.title = "\(self.idleTitle) \(iso)"
            } else {
                button.title = self.idleTitle
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

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
