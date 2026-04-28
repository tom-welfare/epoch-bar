import AppKit
import ApplicationServices

/// Watches for text selection in any AX-visible app. When the selection parses
/// as an epoch-bearing identifier, shows a small tooltip with the decoded ISO
/// date at the cursor.
final class HoverTooltipController {
    private let panel = HoverTooltipPanel()
    private var mouseUpGlobal: Any?
    private var mouseUpLocal: Any?
    private var mouseDownGlobal: Any?
    private var mouseDownLocal: Any?

    // MARK: - Lifecycle

    func start() {
        guard mouseUpGlobal == nil else { return }
        Log.hover.info("starting selection monitor")

        mouseUpGlobal = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.onSelectionPossiblyChanged()
        }
        mouseUpLocal = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.onSelectionPossiblyChanged()
            return event
        }
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
        Diagnostics.shared.recordMouseUp()
        guard Preferences.tooltipEnabled else { return }
        // mouseUp fires before the host app finalises the selection, so wait a beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.checkSelection()
        }
    }

    private func checkSelection() {
        guard AXIsProcessTrusted() else {
            Log.hover.warning("AX not trusted at selection time")
            Diagnostics.shared.recordSelection(.init(
                at: Date(), focusedAppName: nil, focusedAppPID: nil,
                focusedElementRole: nil, elementRoles: [],
                selectedTextLength: nil,
                failureReason: "AX not trusted"
            ))
            return
        }

        let result = readCurrentSelection()
        Diagnostics.shared.recordSelection(result.attempt)

        guard let selection = result.text else {
            Log.hover.debug("no selection text — \(result.attempt.failureReason ?? "?", privacy: .public)")
            return
        }
        guard let parsed = EpochParser.parse(selection) else {
            Log.hover.debug("selection didn't parse as an epoch (\(selection.count) chars)")
            return
        }
        let iso = EpochParser.formatISO(parsed)
        Log.hover.info("showing tooltip for parsed epoch")
        panel.show(text: iso, atCursor: NSEvent.mouseLocation)
    }

    /// Returns the current selection (if any) along with a structured attempt
    /// record describing how we got there. The attempt record is what gets
    /// surfaced in the diagnostics window when nothing parsed.
    private func readCurrentSelection() -> (text: String?, attempt: Diagnostics.SelectionAttempt) {
        var attempt = Diagnostics.SelectionAttempt(
            at: Date(),
            focusedAppName: nil, focusedAppPID: nil,
            focusedElementRole: nil, elementRoles: [],
            selectedTextLength: nil, failureReason: nil
        )

        // 1. Find the focused application via AX, with NSWorkspace as fallback
        //    for cases where AXFocusedApplication transiently returns nothing.
        let app: AXUIElement
        if let viaAX = focusedAppViaAX() {
            app = viaAX.element
            attempt.focusedAppPID = viaAX.pid
            attempt.focusedAppName = viaAX.name
        } else if let viaWorkspace = focusedAppViaWorkspace() {
            app = viaWorkspace.element
            attempt.focusedAppPID = viaWorkspace.pid
            attempt.focusedAppName = viaWorkspace.name + " (via NSWorkspace)"
        } else {
            attempt.failureReason = "no focused app"
            return (nil, attempt)
        }

        // 2. Drill down to the focused UI element.
        var focusedElem: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElem) == .success,
              let elemVal = focusedElem else {
            attempt.failureReason = "no focused element"
            return (nil, attempt)
        }
        let focused = elemVal as! AXUIElement
        attempt.focusedElementRole = role(of: focused)
        attempt.elementRoles = roleChain(from: focused)

        // 3. Read AXSelectedText, walking up if the leaf doesn't carry it.
        if let text = selectedText(in: focused) {
            attempt.selectedTextLength = text.count
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), attempt)
        }
        if let (text, depth) = selectedTextWalkingUp(from: focused) {
            attempt.failureReason = "found via parent walk (\(depth) level\(depth == 1 ? "" : "s") up)"
            attempt.selectedTextLength = text.count
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), attempt)
        }
        attempt.failureReason = "no AXSelectedText on focused element or any of its ancestors"
        return (nil, attempt)
    }

    // MARK: - AX helpers

    private struct FocusedApp { let element: AXUIElement; let pid: pid_t; let name: String }

    private func focusedAppViaAX() -> FocusedApp? {
        let systemWide = AXUIElementCreateSystemWide()
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &ref) == .success,
              let val = ref else { return nil }
        let element = val as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
        return FocusedApp(element: element, pid: pid, name: name)
    }

    private func focusedAppViaWorkspace() -> FocusedApp? {
        guard let running = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(running.processIdentifier)
        return FocusedApp(element: element,
                          pid: running.processIdentifier,
                          name: running.localizedName ?? "pid \(running.processIdentifier)")
    }

    private func selectedText(in element: AXUIElement) -> String? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &v) == .success,
              let text = v as? String, !text.isEmpty else { return nil }
        return text
    }

    private func selectedTextWalkingUp(from element: AXUIElement, maxDepth: Int = 6) -> (String, Int)? {
        var current: AXUIElement = element
        for depth in 1...maxDepth {
            var parent: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let p = parent, CFGetTypeID(p) == AXUIElementGetTypeID() else { return nil }
            current = p as! AXUIElement
            if let text = selectedText(in: current) { return (text, depth) }
        }
        return nil
    }

    private func role(of element: AXUIElement) -> String? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &v) == .success
        else { return nil }
        return v as? String
    }

    /// Build the role chain from `element` up through its AX parents (max 8 levels).
    private func roleChain(from element: AXUIElement, maxDepth: Int = 8) -> [String] {
        var roles: [String] = []
        if let r = role(of: element) { roles.append(r) }
        var current = element
        for _ in 0..<maxDepth {
            var parent: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let p = parent, CFGetTypeID(p) == AXUIElementGetTypeID() else { break }
            current = p as! AXUIElement
            if let r = role(of: current) { roles.append(r) }
        }
        return roles
    }
}
