import AppKit

final class StatusItemController {
    private let statusItem: NSStatusItem
    private let watcher: ClipboardWatcher
    private var currentISO: String?

    private let idleTitle = "⏱"

    init(watcher: ClipboardWatcher) {
        self.watcher = watcher
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = idleTitle

        watcher.onChange = { [weak self] parsed in
            self?.update(parsed: parsed)
        }
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
}
