import AppKit

/// Settings window: enable toggle, colour wells, font + size pickers, and a
/// live preview pill that mirrors the real tooltip.
final class SettingsWindowController: NSWindowController {
    private let enabledSwitch = NSSwitch()
    private let bgWell = NSColorWell()
    private let fgWell = NSColorWell()
    private let bgHexField = NSTextField()
    private let fgHexField = NSTextField()
    private let fontLabel = NSTextField(labelWithString: "")
    private let sizeField = NSTextField()
    private let sizeStepper = NSStepper()

    private let previewContainer = NSView()
    private let previewPill = NSView()
    private let previewLabel = NSTextField(labelWithString: "2025-01-01T00:00:00Z")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "EpochBar Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildLayout(in: window.contentView!)
        loadInitialValues()
        refreshPreview()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func buildLayout(in content: NSView) {
        // Enable toggle row
        let enabledCaption = NSTextField(labelWithString: "Show tooltip on selection")
        enabledCaption.font = NSFont.systemFont(ofSize: 13)
        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged(_:))
        let enabledRow = NSStackView(views: [enabledCaption, NSView(), enabledSwitch])
        enabledRow.orientation = .horizontal
        enabledRow.spacing = 12
        enabledRow.alignment = .centerY
        enabledRow.distribution = .fill

        // Appearance heading
        let appearanceHeading = NSTextField(labelWithString: "Appearance")
        appearanceHeading.font = NSFont.systemFont(ofSize: 14, weight: .semibold)

        // Colour wells with adjacent hex fields
        let bgRow = colorRow(label: "Background", well: bgWell, hex: bgHexField,
                             wellAction: #selector(bgChanged(_:)), hexAction: #selector(bgHexChanged(_:)))
        let fgRow = colorRow(label: "Text", well: fgWell, hex: fgHexField,
                             wellAction: #selector(fgChanged(_:)), hexAction: #selector(fgHexChanged(_:)))

        // Font row
        fontLabel.font = NSFont.systemFont(ofSize: 12)
        fontLabel.textColor = .labelColor
        fontLabel.drawsBackground = false
        fontLabel.isBordered = false
        fontLabel.isEditable = false
        fontLabel.lineBreakMode = .byTruncatingTail
        fontLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let fontCaption = NSTextField(labelWithString: "Font")
        fontCaption.font = NSFont.systemFont(ofSize: 13)
        fontCaption.textColor = .secondaryLabelColor
        fontCaption.widthAnchor.constraint(equalToConstant: 110).isActive = true

        let chooseFontButton = NSButton(title: "Choose…", target: self, action: #selector(chooseFontTapped))
        chooseFontButton.bezelStyle = .rounded

        let fontRow = NSStackView(views: [fontCaption, fontLabel, chooseFontButton])
        fontRow.orientation = .horizontal
        fontRow.spacing = 12
        fontRow.alignment = .centerY

        // Size row — numeric text field + stepper
        let sizeCaption = NSTextField(labelWithString: "Size")
        sizeCaption.font = NSFont.systemFont(ofSize: 13)
        sizeCaption.textColor = .secondaryLabelColor
        sizeCaption.widthAnchor.constraint(equalToConstant: 110).isActive = true

        sizeField.alignment = .right
        sizeField.target = self
        sizeField.action = #selector(sizeFieldChanged(_:))
        sizeField.formatter = {
            let f = NumberFormatter()
            f.minimum = 8
            f.maximum = 36
            f.maximumFractionDigits = 0
            return f
        }()
        sizeField.widthAnchor.constraint(equalToConstant: 56).isActive = true

        sizeStepper.minValue = 8
        sizeStepper.maxValue = 36
        sizeStepper.increment = 1
        sizeStepper.target = self
        sizeStepper.action = #selector(sizeStepperChanged(_:))

        let sizeRow = NSStackView(views: [sizeCaption, sizeField, sizeStepper, NSView()])
        sizeRow.orientation = .horizontal
        sizeRow.spacing = 8
        sizeRow.alignment = .centerY

        // Preview pill
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        previewContainer.layer?.cornerRadius = 4

        previewPill.translatesAutoresizingMaskIntoConstraints = false
        previewPill.wantsLayer = true
        previewPill.layer?.cornerRadius = 4

        previewLabel.drawsBackground = false
        previewLabel.isBordered = false
        previewLabel.isEditable = false
        previewLabel.alignment = .center
        previewLabel.translatesAutoresizingMaskIntoConstraints = false

        previewContainer.addSubview(previewPill)
        previewPill.addSubview(previewLabel)

        // Reset
        let resetButton = NSButton(title: "Reset all to defaults", target: self, action: #selector(resetTapped))
        resetButton.bezelStyle = .rounded

        // Root stack
        let divider1 = horizontalDivider()
        let stack = NSStackView(views: [
            enabledRow,
            divider1,
            appearanceHeading,
            bgRow, fgRow,
            fontRow, sizeRow,
            previewContainer,
            resetButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            enabledRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            divider1.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            bgRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            fgRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            fontRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            sizeRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),

            previewContainer.heightAnchor.constraint(equalToConstant: 56),
            previewContainer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),

            previewPill.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            previewPill.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),

            previewLabel.topAnchor.constraint(equalTo: previewPill.topAnchor, constant: 5),
            previewLabel.bottomAnchor.constraint(equalTo: previewPill.bottomAnchor, constant: -5),
            previewLabel.leadingAnchor.constraint(equalTo: previewPill.leadingAnchor, constant: 10),
            previewLabel.trailingAnchor.constraint(equalTo: previewPill.trailingAnchor, constant: -10),
        ])
    }

    private func colorRow(label: String, well: NSColorWell, hex: NSTextField,
                          wellAction: Selector, hexAction: Selector) -> NSView {
        let caption = NSTextField(labelWithString: label)
        caption.font = NSFont.systemFont(ofSize: 13)
        caption.textColor = .secondaryLabelColor
        caption.widthAnchor.constraint(equalToConstant: 110).isActive = true

        well.target = self
        well.action = wellAction
        well.translatesAutoresizingMaskIntoConstraints = false
        well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        well.heightAnchor.constraint(equalToConstant: 26).isActive = true

        hex.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        hex.placeholderString = "#RRGGBB"
        hex.target = self
        hex.action = hexAction
        hex.translatesAutoresizingMaskIntoConstraints = false
        hex.widthAnchor.constraint(equalToConstant: 108).isActive = true

        let row = NSStackView(views: [caption, well, hex, NSView()])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func horizontalDivider() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.separatorColor.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func loadInitialValues() {
        enabledSwitch.state = Preferences.tooltipEnabled ? .on : .off
        bgWell.color = Preferences.tooltipBackground
        fgWell.color = Preferences.tooltipForeground
        bgHexField.stringValue = Preferences.tooltipBackground.ep_hexString
        fgHexField.stringValue = Preferences.tooltipForeground.ep_hexString
        sizeField.doubleValue = Double(Preferences.tooltipFontSize)
        sizeStepper.doubleValue = Double(Preferences.tooltipFontSize)
        updateFontLabel()
    }

    private func updateFontLabel() {
        let font = Preferences.tooltipFont
        let displayName = font.displayName ?? font.fontName
        fontLabel.stringValue = "\(displayName) · \(Int(font.pointSize))pt"
    }

    // MARK: - Actions

    @objc private func enabledChanged(_ sender: NSSwitch) {
        Preferences.tooltipEnabled = (sender.state == .on)
    }

    @objc private func bgChanged(_ sender: NSColorWell) {
        Preferences.tooltipBackground = sender.color
        bgHexField.stringValue = sender.color.ep_hexString
        refreshPreview()
    }

    @objc private func fgChanged(_ sender: NSColorWell) {
        Preferences.tooltipForeground = sender.color
        fgHexField.stringValue = sender.color.ep_hexString
        refreshPreview()
    }

    @objc private func bgHexChanged(_ sender: NSTextField) {
        applyHex(sender.stringValue, toWell: bgWell, field: sender) { color in
            Preferences.tooltipBackground = color
        }
    }

    @objc private func fgHexChanged(_ sender: NSTextField) {
        applyHex(sender.stringValue, toWell: fgWell, field: sender) { color in
            Preferences.tooltipForeground = color
        }
    }

    private func applyHex(_ raw: String, toWell well: NSColorWell, field: NSTextField, commit: (NSColor) -> Void) {
        guard let color = NSColor.ep_fromHex(raw) else {
            NSSound.beep()
            field.stringValue = well.color.ep_hexString   // revert
            return
        }
        well.color = color
        field.stringValue = color.ep_hexString            // normalise to #RRGGBB
        commit(color)
        refreshPreview()
    }

    @objc private func sizeFieldChanged(_ sender: NSTextField) {
        let value = sender.doubleValue
        setSize(CGFloat(value))
    }

    @objc private func sizeStepperChanged(_ sender: NSStepper) {
        setSize(CGFloat(sender.doubleValue))
    }

    private func setSize(_ size: CGFloat) {
        Preferences.tooltipFontSize = size
        sizeField.doubleValue = Double(size)
        sizeStepper.doubleValue = Double(size)
        updateFontLabel()
        refreshPreview()
    }

    @objc private func chooseFontTapped() {
        // Make this controller the receiver of changeFont: and the font panel's target.
        window?.makeFirstResponder(self)
        NSFontManager.shared.target = self
        NSFontManager.shared.setSelectedFont(Preferences.tooltipFont, isMultiple: false)
        NSFontPanel.shared.orderFront(nil)
    }

    /// Called by NSFontManager when the user picks a font / size in the panel.
    @objc func changeFont(_ sender: Any?) {
        let fm = (sender as? NSFontManager) ?? NSFontManager.shared
        let newFont = fm.convert(Preferences.tooltipFont)
        Preferences.tooltipFontName = newFont.fontName
        Preferences.tooltipFontSize = newFont.pointSize
        sizeField.doubleValue = Double(newFont.pointSize)
        sizeStepper.doubleValue = Double(newFont.pointSize)
        updateFontLabel()
        refreshPreview()
    }

    @objc private func resetTapped() {
        Preferences.resetAll()
        loadInitialValues()
        refreshPreview()
    }

    private func refreshPreview() {
        previewPill.layer?.backgroundColor = Preferences.tooltipBackground.cgColor
        previewLabel.textColor = Preferences.tooltipForeground
        previewLabel.font = Preferences.tooltipFont
    }
}
