import AppKit

enum DesktopApp: String, Sendable {
    case claude, codex, capy
    var name: String { self == .claude ? "Claude" : self == .codex ? "Codex" : "Capy" }
    var bundleIDs: [String] { self == .claude ? ClaudeDesktopMonitor.bundleIdentifiers : self == .codex ? ["com.openai.codex"] : ["ai.capy.desktop"] }
    @MainActor var applicationURL: URL? {
        bundleIDs.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
    }
    @MainActor var icon: NSImage? {
        guard let url = applicationURL else { return nil }
        if self == .codex, let icon = NSImage(contentsOf: url.appendingPathComponent("Contents/Resources/icon-codex-light.png")) { return icon }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    func chatURL(_ id: String) -> URL? {
        if self == .capy {
            guard id.range(of: "^jam_[0-9A-HJKMNP-TV-Z]{26}$", options: .regularExpression) != nil else { return nil }
            return URL(string: "capy://app/thread/" + id)
        }
        if self == .claude { return ClaudeDesktopNavigation.url(sessionID: id) }
        guard UUID(uuidString: id) != nil else { return nil }
        return URL(string: "codex://threads/\(id)")
    }
}
