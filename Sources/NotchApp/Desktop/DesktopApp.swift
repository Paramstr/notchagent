import AppKit

enum DesktopApp: String, Sendable {
    case claude, codex
    var name: String { self == .claude ? "Claude" : "Codex" }
    var bundleIDs: [String] { self == .claude ? ClaudeDesktopMonitor.bundleIdentifiers : ["com.openai.codex"] }
    @MainActor var applicationURL: URL? {
        bundleIDs.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
    }
    func chatURL(_ id: String) -> URL? {
        if self == .claude { return ClaudeDesktopNavigation.url(sessionID: id) }
        guard UUID(uuidString: id) != nil else { return nil }
        return URL(string: "codex://threads/\(id)")
    }
}
