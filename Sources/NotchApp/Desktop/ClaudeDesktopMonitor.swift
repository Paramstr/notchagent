import AppKit
import Observation

@Observable
@MainActor
final class ClaudeDesktopMonitor {
    nonisolated static let bundleIdentifiers = ["com.anthropic.claudefordesktop", "com.anthropic.claude"]

    private(set) var sessions: [ClaudeDesktopSession] = []
    private(set) var message: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var reader = ClaudeDesktopLogReader()

    @ObservationIgnored private var codexReader = CodexDesktopReader()

    func start(onChange: @escaping @MainActor ([ClaudeDesktopSession], Bool) -> Void) {
        guard task == nil else { return }
        task = Task { [weak self] in
            var previousApps: Set<String> = []
            while !Task.isCancelled {
                guard let self else { return }
                let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
                var next: [ClaudeDesktopSession] = []
                var live = !previousApps.isEmpty
                var errors: [String] = []
                if Self.bundleIdentifiers.contains(where: running.contains) {
                    if !Self.bundleIdentifiers.contains(where: previousApps.contains) { self.reader = ClaudeDesktopLogReader(); live = false }
                    do {
                        next += try await self.reader.read()
                        if await self.reader.replayedHistory { live = false }
                    } catch { errors.append("Waiting for readable Claude Desktop logs.") }
                }
                if running.contains("com.openai.codex") {
                    if !previousApps.contains("com.openai.codex") { live = false }
                    do { next += try await self.codexReader.read() }
                    catch { errors.append("Waiting for readable Codex Desktop session data.") }
                }
                guard !Task.isCancelled else { return }
                next.sort { $0.updatedAt > $1.updatedAt }
                self.message = errors.isEmpty ? nil : errors.joined(separator: " ")
                if next != self.sessions { self.sessions = next; onChange(next, live) }
                previousApps = running
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        sessions = []
    }

    func openClaude(sessionID: String) {
        let provider = sessions.first(where: { $0.id == sessionID })?.app ?? .claude
        guard let deepLink = provider.chatURL(sessionID), let appURL = provider.applicationURL else {
            message = "This chat cannot be opened in \(provider.name)."
            return
        }
        NSWorkspace.shared.open([deepLink], withApplicationAt: appURL, configuration: .init()) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if error != nil {
                    self.message = "Could not open this chat in \(provider.name)."
                } else {
                    if provider == .claude { await self.reader.markViewed(sessionID) }
                }
            }
        }
    }
}
