import AppKit

final class DiagnosticsWindowController: NSWindowController {
    private let textView = NSTextView()
    private let copyButton = NSButton()
    private let refreshButton = NSButton()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "EpochBar Diagnostics"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildLayout(in: window.contentView!)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        refresh()
    }

    private func buildLayout(in content: NSView) {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        scroll.documentView = textView

        refreshButton.title = "Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refresh)

        copyButton.title = "Copy to clipboard"
        copyButton.bezelStyle = .rounded
        copyButton.keyEquivalent = "\r"
        copyButton.target = self
        copyButton.action = #selector(copyToClipboard)

        let buttons = NSStackView(views: [NSView(), refreshButton, copyButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let stack = NSStackView(views: [scroll, buttons])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 360),
        ])
    }

    @objc private func refresh() {
        textView.string = Diagnostics.shared.reportText()
    }

    @objc private func copyToClipboard() {
        refresh()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(textView.string, forType: .string)
    }
}
