import AppKit

final class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastWrittenValue: String?
    private let pasteboard = NSPasteboard.general

    /// Called on the main run loop whenever the clipboard changes to a new value.
    /// `parsed` is non-nil when the new contents parse as a supported epoch.
    var onChange: ((ParsedEpoch?) -> Void)?

    func start() {
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called by the status item whenever we write to the pasteboard ourselves,
    /// so the next tick doesn't re-evaluate our own output.
    func markJustWrote(_ value: String) {
        lastWrittenValue = value
    }

    private func tick() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        let contents = pasteboard.string(forType: .string)
        if let contents, contents == lastWrittenValue {
            return
        }

        let parsed = contents.flatMap(EpochParser.parse)
        onChange?(parsed)
    }
}
