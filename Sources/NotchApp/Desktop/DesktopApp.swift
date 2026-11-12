import AppKit

enum DesktopApp: String, Sendable {
    case claude, codex
    var name: String { self == .claude ? "Claude" : "Codex" }
    var bundleIDs: [String] { self == .claude ? ClaudeDesktopMonitor.bundleIdentifiers : ["com.openai.codex"] }
    @MainActor var applicationURL: URL? {
        bundleIDs.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
    }
    @MainActor var icon: NSImage? {
        guard let url = applicationURL else { return nil }
        if self == .codex, let icon = NSImage(contentsOf: url.appendingPathComponent("Contents/Resources/icon-codex-light.png")) { return icon }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    func chatURL(_ id: String) -> URL? {
        if self == .claude { return ClaudeDesktopNavigation.url(sessionID: id) }
        guard UUID(uuidString: id) != nil else { return nil }
        return URL(string: "codex://threads/\(id)")
    }
}
