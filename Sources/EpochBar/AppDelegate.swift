import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let watcher = ClipboardWatcher()
    private let hover = HoverTooltipController()
    private var controller: StatusItemController?
    private var hoverRetryTimer: Timer?

    static func main() {
        let app = NSApplication.shared

        if isAlreadyRunning() {
            let alert = NSAlert()
            alert.messageText = "EpochBar is already running"
            alert.informativeText = "Another copy of EpochBar is already in the menu bar. This one will now quit."
            alert.alertStyle = .warning
            alert.runModal()
            exit(0)
        }

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private static func isAlreadyRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let ourPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != ourPID }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController(watcher: watcher)
        watcher.start()
        startHoverWhenTrusted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher.stop()
        hover.stop()
        hoverRetryTimer?.invalidate()
    }

    /// Start hover tooltips if Accessibility is already trusted; otherwise prompt
    /// and poll until the user grants permission, then start.
    private func startHoverWhenTrusted() {
        if HoverTooltipController.isAccessibilityTrusted {
            hover.start()
            return
        }
        HoverTooltipController.requestAccessibilityPrompt()
        hoverRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if HoverTooltipController.isAccessibilityTrusted {
                self.hover.start()
                timer.invalidate()
                self.hoverRetryTimer = nil
            }
        }
    }
}
