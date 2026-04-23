import AppKit
import ApplicationServices

/// Watches for text selection in any AX-visible app. When the selection parses
/// as an epoch-bearing identifier, shows a small tooltip with the decoded ISO
/// date at the cursor. Retained name for continuity; behaviour is selection-
/// based, not hover-based.
final class HoverTooltipController {
    private let panel = HoverTooltipPanel()
    private var mouseUpGlobal: Any?
    private var mouseUpLocal: Any?
    private var mouseDownGlobal: Any?
    private var mouseDownLocal: Any?

    // MARK: - Lifecycle

    func start() {
        guard mouseUpGlobal == nil else { return }

        mouseUpGlobal = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.onSelectionPossiblyChanged()
        }
        mouseUpLocal = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.onSelectionPossiblyChanged()
            return event
        }
        // Dismiss the previous tooltip the moment the user starts a new interaction.
        mouseDownGlobal = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.panel.hide()
        }
        mouseDownLocal = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.panel.hide()
            return event
        }
    }

    func stop() {
        for monitor in [mouseUpGlobal, mouseUpLocal, mouseDownGlobal, mouseDownLocal] {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
        mouseUpGlobal = nil; mouseUpLocal = nil
        mouseDownGlobal = nil; mouseDownLocal = nil
        panel.hide()
    }

    // MARK: - Permission helpers

    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPrompt() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Selection handling

    private func onSelectionPossiblyChanged() {
        guard AXIsProcessTrusted() else { return }

        // mouseUp fires on the down-stroke's release, but the selection isn't always
        // propagated into AX yet. A tiny delay lets AppKit finalise the selection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.checkSelection()
        }
    }

    private func checkSelection() {
        guard Preferences.tooltipEnabled else { return }
        guard let selection = currentFocusedSelection(),
              let parsed = EpochParser.parse(selection) else {
            return
        }
        let iso = EpochParser.formatISO(parsed)
        panel.show(text: iso, atCursor: NSEvent.mouseLocation)
    }

    /// Read the selected text from the currently focused UI element, trimmed.
    /// Returns nil if nothing is selected, the app doesn't expose selection,
    /// or the selected range is too short to be a plausible timestamp.
    private func currentFocusedSelection() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var app: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &app) == .success,
              let appVal = app else { return nil }
        let appElement = appVal as! AXUIElement

        var element: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &element) == .success,
              let elemVal = element else { return nil }
        let focused = elemVal as! AXUIElement

        var selected: AnyObject?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 10 ? trimmed : nil
    }
}
