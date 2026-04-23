import AppKit

/// A floating, non-activating panel that renders a small teal pill with an ISO
/// string, shown just above a rectangle passed by the caller.
final class HoverTooltipPanel {
    private let panel: NSPanel
    private let host: NSView
    private let label: NSTextField

    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 4
    private let cornerRadius: CGFloat = 4
    /// Offset from the cursor so the tooltip sits slightly to the right and above.
    private let cursorOffset: NSSize = NSSize(width: 14, height: 16)

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 24),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        host = NSView(frame: NSRect(x: 0, y: 0, width: 140, height: 24))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor(calibratedRed: 0.37, green: 0.92, blue: 0.83, alpha: 0.96).cgColor
        host.layer?.cornerRadius = cornerRadius
        host.layer?.masksToBounds = true

        label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .black
        label.drawsBackground = false
        label.isBordered = false
        label.alignment = .center
        label.usesSingleLineMode = true

        host.addSubview(label)
        panel.contentView = host
    }

    func show(text: String, atCursor cursor: NSPoint) {
        label.stringValue = text
        label.sizeToFit()

        let width = label.frame.width + horizontalPadding * 2
        let height = label.frame.height + verticalPadding * 2

        label.frame = NSRect(x: horizontalPadding, y: verticalPadding,
                             width: label.frame.width, height: label.frame.height)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)

        var x = cursor.x + cursorOffset.width
        var y = cursor.y + cursorOffset.height
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main {
            let vis = screen.visibleFrame
            if x + width > vis.maxX - 4 {
                x = cursor.x - cursorOffset.width - width   // flip to the left
            }
            if y + height > vis.maxY - 4 {
                y = cursor.y - cursorOffset.height - height // flip below the cursor
            }
            x = max(vis.minX + 4, min(x, vis.maxX - width - 4))
            y = max(vis.minY + 4, min(y, vis.maxY - height - 4))
        }

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        if panel.isVisible { panel.orderOut(nil) }
    }
}
