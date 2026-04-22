import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let watcher = ClipboardWatcher()
    private var controller: StatusItemController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController(watcher: watcher)
        watcher.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher.stop()
    }
}
