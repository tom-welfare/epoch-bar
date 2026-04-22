import AppKit

final class StatusItemController {
    private let statusItem: NSStatusItem
    private let idleTitle = "⏱"

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = idleTitle
    }
}
