import AppKit

/// Thin wrapper around UserDefaults for all user-tweakable tooltip settings.
enum Preferences {
    private static let defaults = UserDefaults.standard

    private static let bgKey       = "tooltipBackgroundColor"
    private static let fgKey       = "tooltipTextColor"
    private static let fontKey     = "tooltipFontName"      // empty string = system monospace
    private static let sizeKey     = "tooltipFontSize"      // 0 = default
    private static let enabledKey  = "tooltipEnabled"

    // MARK: - Defaults

    static let defaultBackground = NSColor(calibratedRed: 0.37, green: 0.92, blue: 0.83, alpha: 0.96)
    static let defaultForeground = NSColor.black
    static let defaultFontSize: CGFloat = 11
    static let defaultWeight: NSFont.Weight = .medium

    // MARK: - Background / foreground

    static var tooltipBackground: NSColor {
        get { defaults.ep_color(forKey: bgKey) ?? defaultBackground }
        set { defaults.ep_setColor(newValue, forKey: bgKey) }
    }

    static var tooltipForeground: NSColor {
        get { defaults.ep_color(forKey: fgKey) ?? defaultForeground }
        set { defaults.ep_setColor(newValue, forKey: fgKey) }
    }

    // MARK: - Font

    /// Stored font name; empty means "system monospace".
    static var tooltipFontName: String {
        get { defaults.string(forKey: fontKey) ?? "" }
        set { defaults.set(newValue, forKey: fontKey) }
    }

    static var tooltipFontSize: CGFloat {
        get {
            let raw = defaults.double(forKey: sizeKey)
            return raw > 0 ? CGFloat(raw) : defaultFontSize
        }
        set { defaults.set(Double(newValue), forKey: sizeKey) }
    }

    static var tooltipFont: NSFont {
        let size = tooltipFontSize
        let name = tooltipFontName
        if !name.isEmpty, let custom = NSFont(name: name, size: size) {
            return custom
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: defaultWeight)
    }

    // MARK: - Enabled toggle

    static var tooltipEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    // MARK: - Reset

    static func resetAll() {
        [bgKey, fgKey, fontKey, sizeKey, enabledKey].forEach { defaults.removeObject(forKey: $0) }
    }
}

extension NSColor {
    /// Parse "#RRGGBB", "RRGGBB", "#RGB", "RGB", "#RRGGBBAA", "RRGGBBAA".
    /// Returns nil if the string isn't a valid hex colour.
    static func ep_fromHex(_ raw: String) -> NSColor? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard [3, 6, 8].contains(s.count),
              s.allSatisfy({ "0123456789ABCDEF".contains($0) }) else { return nil }
        let expanded: String = (s.count == 3) ? s.map { "\($0)\($0)" }.joined() : s
        func byte(_ offset: Int) -> CGFloat {
            let start = expanded.index(expanded.startIndex, offsetBy: offset)
            let end = expanded.index(start, offsetBy: 2)
            return CGFloat(UInt8(expanded[start..<end], radix: 16) ?? 0) / 255
        }
        let r = byte(0), g = byte(2), b = byte(4)
        let a: CGFloat = (expanded.count == 8) ? byte(6) : 1
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }

    /// Uppercase "#RRGGBB" or "#RRGGBBAA" if alpha < 1.
    var ep_hexString: String {
        let rgba = usingColorSpace(.deviceRGB) ?? self
        let r = Int((rgba.redComponent   * 255).rounded())
        let g = Int((rgba.greenComponent * 255).rounded())
        let b = Int((rgba.blueComponent  * 255).rounded())
        let a = Int((rgba.alphaComponent * 255).rounded())
        return a == 255
            ? String(format: "#%02X%02X%02X", r, g, b)
            : String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}

private extension UserDefaults {
    func ep_color(forKey key: String) -> NSColor? {
        guard let data = data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    func ep_setColor(_ color: NSColor, forKey key: String) {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
        set(data, forKey: key)
    }
}
