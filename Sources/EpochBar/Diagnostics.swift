import AppKit
import ApplicationServices
import OSLog

/// Central log destination. Tail with: `log stream --predicate 'subsystem == "dev.tlw.epoch-bar"'`
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.tlw.epoch-bar"
    static let app    = Logger(subsystem: subsystem, category: "app")
    static let hover  = Logger(subsystem: subsystem, category: "hover")
    static let status = Logger(subsystem: subsystem, category: "status")
}

/// Snapshot of runtime state that helps users diagnose why selection tooltips
/// or the menu bar icon aren't behaving on their machine. Everything here is
/// safe to copy into a bug report — no clipboard contents, no selected text.
final class Diagnostics {
    static let shared = Diagnostics()

    // MARK: - Last-event recorders

    private(set) var lastMouseUp: Date?
    private(set) var lastSelectionAttempt: SelectionAttempt?
    private(set) var statusItemButtonPresent = false

    func recordMouseUp() {
        lastMouseUp = Date()
    }

    func recordSelection(_ attempt: SelectionAttempt) {
        lastSelectionAttempt = attempt
    }

    func recordStatusItemButton(present: Bool) {
        statusItemButtonPresent = present
    }

    // MARK: - Snapshot

    struct SelectionAttempt {
        var at: Date
        var focusedAppName: String?
        var focusedAppPID: pid_t?
        var focusedElementRole: String?
        var elementRoles: [String]   // role chain from focused → ancestors
        var selectedTextLength: Int?
        var failureReason: String?
    }

    /// Renders a multi-line, copyable summary of current diagnostic state.
    func reportText() -> String {
        let info = ProcessInfo.processInfo
        let bundle = Bundle.main
        var out: [String] = []
        out.append("EpochBar diagnostics — \(ISO8601DateFormatter().string(from: Date()))")
        out.append("")
        out.append("App")
        out.append("  version              \(bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
        out.append("  build                \(bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?")")
        out.append("  bundle id            \(bundle.bundleIdentifier ?? "?")")
        out.append("  bundle path          \(bundle.bundlePath)")
        out.append("  arch                 \(machineArch())")
        out.append("  pid                  \(info.processIdentifier)")
        out.append("")
        out.append("System")
        out.append("  macOS                \(info.operatingSystemVersionString)")
        out.append("  hostname             \(info.hostName)")
        out.append("")
        out.append("Permissions")
        out.append("  AX trusted           \(AXIsProcessTrusted())")
        out.append("")
        out.append("Status item")
        out.append("  button present       \(statusItemButtonPresent)")
        out.append("")
        out.append("Last mouse-up         \(lastMouseUp.map(format) ?? "—")")
        out.append("Last selection attempt")
        if let s = lastSelectionAttempt {
            out.append("  at                   \(format(s.at))")
            out.append("  focused app          \(s.focusedAppName ?? "?")  pid=\(s.focusedAppPID.map(String.init) ?? "?")")
            out.append("  focused element role \(s.focusedElementRole ?? "?")")
            if !s.elementRoles.isEmpty {
                out.append("  AX role chain        \(s.elementRoles.joined(separator: " ← "))")
            }
            if let len = s.selectedTextLength {
                out.append("  selected text len    \(len)")
            }
            if let reason = s.failureReason {
                out.append("  outcome              \(reason)")
            }
        } else {
            out.append("  (none yet — try selecting an epoch in another app)")
        }
        out.append("")
        out.append("Preferences")
        out.append("  tooltip enabled      \(Preferences.tooltipEnabled)")
        out.append("  font                 \(Preferences.tooltipFont.fontName) @ \(Int(Preferences.tooltipFontSize))pt")
        return out.joined(separator: "\n")
    }

    private func format(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: d)
    }

    private func machineArch() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let arch = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return arch
    }
}
