import AppKit
import Observation

@Observable
@MainActor
final class ClaudeDesktopMonitor {
    static let bundleIdentifiers = ["com.anthropic.claudefordesktop", "com.anthropic.claude"]

    private(set) var sessions: [ClaudeDesktopSession] = []
    private(set) var message: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var reader = ClaudeDesktopLogReader()

    func start(onChange: @escaping @MainActor ([ClaudeDesktopSession], Bool) -> Void) {
        guard task == nil else { return }
        task = Task { [weak self] in
            var wasRunning = false
            while !Task.isCancelled {
                guard let self else { return }
                let running = NSWorkspace.shared.runningApplications.contains {
                    $0.bundleIdentifier.map(Self.bundleIdentifiers.contains) ?? false
                }
                if running {
                    if !wasRunning { self.reader = ClaudeDesktopLogReader() }
                    do {
                        let next = try await self.reader.read()
                        let replayed = await self.reader.replayedHistory
                        guard !Task.isCancelled else { return }
                        self.message = nil
                        if next != self.sessions {
                            self.sessions = next
                            onChange(next, wasRunning && !replayed)
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        self.message = "Waiting for readable Claude Desktop logs. Start a local Code session in Claude."
                        if !self.sessions.isEmpty {
                            self.sessions = []
                            onChange([], false)
                        }
                    }
                } else {
                    self.message = "Claude Desktop is not running. Open Claude and start a local Code session."
                    if !self.sessions.isEmpty {
                        self.sessions = []
                        onChange([], false)
                    }
                }
                wasRunning = running
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        sessions = []
    }

    func openClaude(sessionID: String) {
        // No private deep link or synthetic keystrokes: app activation only.
        guard let url = Self.bundleIdentifiers.lazy.compactMap({
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }).first else {
            message = "Claude Desktop is not installed."
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
        Task { await reader.markViewed(sessionID) }
    }
}
