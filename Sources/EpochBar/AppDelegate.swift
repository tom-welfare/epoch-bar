import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let watcher = ClipboardWatcher()
    private var controller: StatusItemController?

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher.stop()
    }
}
