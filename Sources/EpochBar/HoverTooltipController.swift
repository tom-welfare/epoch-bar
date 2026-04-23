import AppKit
import ApplicationServices

/// Watches the global cursor position, asks the Accessibility API for the text
/// under it, and — when a token there parses as an epoch-bearing identifier —
/// shows a small floating tooltip with the decoded ISO date.
final class HoverTooltipController {
    private let panel = HoverTooltipPanel()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var debounceTimer: Timer?

    private var lastTokenText: String?
    private var lastTokenScreenRect: NSRect = .zero

    /// Time the cursor must dwell before we query AX. Keeps mouse-move traffic
    /// cheap and avoids flickering tooltips during active movement.
    private let dwellInterval: TimeInterval = 0.14

    // MARK: - Lifecycle

    func start() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.onMouseMoved()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.onMouseMoved()
            return event
        }
    }

    func stop() {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
        if let m = localMouseMonitor  { NSEvent.removeMonitor(m); localMouseMonitor = nil }
        debounceTimer?.invalidate()
        debounceTimer = nil
        panel.hide()
        lastTokenText = nil
        lastTokenScreenRect = .zero
    }

    // MARK: - Permission helpers

    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPrompt() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Mouse handling

    private func onMouseMoved() {
        let screenPoint = NSEvent.mouseLocation

        // Still inside the current tooltip's token — do nothing.
        if lastTokenText != nil, lastTokenScreenRect.contains(screenPoint) { return }

        // Left the token — hide immediately, then debounce a re-check.
        if lastTokenText != nil {
            panel.hide()
            lastTokenText = nil
            lastTokenScreenRect = .zero
        }

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: dwellInterval, repeats: false) { [weak self] _ in
            self?.performHoverCheck()
        }
    }

    private func performHoverCheck() {
        guard AXIsProcessTrusted() else { return }
        let screenPoint = NSEvent.mouseLocation
        guard let (token, axRect) = tokenUnderCursor(screenPoint: screenPoint),
              let parsed = EpochParser.parse(token) else {
            return
        }
        let iso = EpochParser.formatISO(parsed)
        let screenRect = axRectToScreenRect(axRect)
        lastTokenText = token
        lastTokenScreenRect = screenRect
        panel.show(text: iso, atCursor: screenPoint)
    }

    // MARK: - Accessibility query

    private func tokenUnderCursor(screenPoint: NSPoint) -> (String, CGRect)? {
        let axPoint = screenToAxPoint(screenPoint)
        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            systemWide, Float(axPoint.x), Float(axPoint.y), &elementRef
        )
        guard result == .success, let element = elementRef else { return nil }

        guard let fullText = axString(from: element), !fullText.isEmpty else { return nil }
        let ns = fullText as NSString

        // Fast path: ask AX for the character index at the cursor.
        let range: NSRange
        if let idx = axCharIndex(at: axPoint, element: element),
           let expanded = expandToken(in: ns, at: idx) {
            range = expanded
        } else if let scanned = firstParseableTokenContaining(axPoint: axPoint, in: ns, element: element) {
            range = scanned
        } else {
            return nil
        }

        let token = ns.substring(with: range)
        guard EpochParser.parse(token) != nil else { return nil }

        let axRect = axRectForRange(range, element: element)
            ?? CGRect(x: axPoint.x - 1, y: axPoint.y - 1, width: 2, height: 2)
        return (token, axRect)
    }

    private func axString(from element: AXUIElement) -> String? {
        var v: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &v) == .success,
           let s = v as? String, !s.isEmpty {
            return s
        }
        return nil
    }

    private func axCharIndex(at point: CGPoint, element: AXUIElement) -> Int? {
        var p = point
        guard let posValue = AXValueCreate(.cgPoint, &p) else { return nil }
        var result: AnyObject?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXRangeForPositionParameterizedAttribute as CFString,
            posValue,
            &result
        )
        guard status == .success, let axVal = result else { return nil }
        var r = CFRange()
        AXValueGetValue(axVal as! AXValue, .cfRange, &r)
        return r.location
    }

    private func axRectForRange(_ range: NSRange, element: AXUIElement) -> CGRect? {
        var r = CFRange(location: range.location, length: range.length)
        guard let rangeVal = AXValueCreate(.cfRange, &r) else { return nil }
        var result: AnyObject?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeVal,
            &result
        )
        guard status == .success, let axVal = result else { return nil }
        var rect = CGRect.zero
        AXValueGetValue(axVal as! AXValue, .cgRect, &rect)
        return rect
    }

    // MARK: - Token scanning

    /// Expand from a character index outward to the nearest whitespace/newline
    /// boundary. Returns the range of the containing token, or nil if the cursor
    /// is sitting on whitespace.
    private func expandToken(in ns: NSString, at index: Int) -> NSRange? {
        guard index >= 0, index < ns.length else { return nil }
        if isBoundaryChar(ns.character(at: index)) { return nil }
        var start = index
        while start > 0, !isBoundaryChar(ns.character(at: start - 1)) { start -= 1 }
        var end = index
        while end < ns.length, !isBoundaryChar(ns.character(at: end)) { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    /// Fallback for apps where kAXRangeForPositionParameterizedAttribute isn't
    /// implemented. Scans the whole text for whitespace-delimited tokens that
    /// parse, gets each one's screen rect, and returns the first that contains
    /// the cursor.
    private func firstParseableTokenContaining(axPoint: CGPoint, in ns: NSString, element: AXUIElement) -> NSRange? {
        let len = ns.length
        var i = 0
        while i < len {
            while i < len, isBoundaryChar(ns.character(at: i)) { i += 1 }
            var end = i
            while end < len, !isBoundaryChar(ns.character(at: end)) { end += 1 }
            if end > i {
                let r = NSRange(location: i, length: end - i)
                if r.length >= 10 {
                    let sub = ns.substring(with: r)
                    if EpochParser.parse(sub) != nil,
                       let rect = axRectForRange(r, element: element),
                       rect.contains(axPoint) {
                        return r
                    }
                }
            }
            i = end + 1
        }
        return nil
    }

    private func isBoundaryChar(_ c: unichar) -> Bool {
        if let s = Unicode.Scalar(c) {
            return CharacterSet.whitespacesAndNewlines.contains(s)
        }
        return true
    }

    // MARK: - Coordinate conversion

    /// NSEvent / NSScreen use Cocoa (bottom-left origin). AX uses top-left origin
    /// pinned to the primary display.
    private func screenToAxPoint(_ p: NSPoint) -> CGPoint {
        guard let primary = NSScreen.screens.first else { return p }
        return CGPoint(x: p.x, y: primary.frame.maxY - p.y)
    }

    private func axRectToScreenRect(_ r: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return r }
        return NSRect(
            x: r.origin.x,
            y: primary.frame.maxY - r.origin.y - r.height,
            width: r.width,
            height: r.height
        )
    }
}
