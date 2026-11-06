import Foundation
import AppKit
import HerdrClient
import Testing
@testable import NotchApp

/// Synthetic metadata examples; no user logs or prompt captures.
@Suite("Claude Desktop log adapter")
struct ClaudeDesktopTests {
    let a = "local_11111111-1111-1111-1111-111111111111"
    let b = "local_22222222-2222-2222-2222-222222222222"
    let request = "33333333-3333-3333-3333-333333333333"
    let now = Date()

    func line(_ message: String) -> String { "2026-11-05 12:00:00 [info] \(message)" }

    @Test func sessionsAndPermissionCorrelation() {
        var state = ClaudeDesktopLogState()
        state.consume(line("Starting local session \(a) in /example/Project One"), at: now)
        state.consume(line("Starting local session \(b) in /example/Project Two"), at: now)
        state.consume(line("Emitted tool permission request \(request) for Bash in session \(a)"), at: now)
        state.consume(line("[Stop hook] Query completed for session \(b)"), at: now)
        #expect(state.sessions[a]?.status == .blocked)
        #expect(state.sessions[a]?.project == "Project One")
        #expect(state.sessions[b]?.status == .done)
        state.consume(line("Received permission response for \(request): once (tool: Bash)"), at: now)
        #expect(state.sessions[a]?.status == .working)
        #expect(state.sessions[b]?.status == .done)
    }

    @Test func multiplePendingPermissionsRemainBlocked() {
        var state = ClaudeDesktopLogState()
        let second = "44444444-4444-4444-4444-444444444444"
        state.consume(line("Emitted tool permission request \(request) for Bash in session \(a)"), at: now)
        state.consume(line("Emitted tool permission request \(second) for Read in session \(a)"), at: now)
        state.consume(line("Received permission response for \(request): once (tool: Bash)"), at: now)
        #expect(state.sessions[a]?.status == .blocked)
        state.consume(line("Received permission response for \(second): once (tool: Read)"), at: now)
        #expect(state.sessions[a]?.status == .working)
    }

    @Test func unknownAndUnattributedEventsDoNotChangeSessions() {
        var state = ClaudeDesktopLogState()
        state.consume(line("LocalSessions.sendMessage: sessionId=\(a), messageLength=12"), at: now)
        state.consume(line("Received permission response for \(request): once (tool: Bash)"), at: now)
        state.consume(line("User text: [Stop hook] Query completed for session \(a)"), at: now)
        state.consume(line("[Stop hook] Query completed for session \(a)::c8"), at: now)
        #expect(state.sessions.count == 1)
        #expect(state.sessions[a]?.status == .working)
    }

    @Test func archiveAndCompletionInvalidatePendingRequests() {
        var state = ClaudeDesktopLogState()
        state.consume(line("Emitted tool permission request \(request) for Bash in session \(a)"), at: now)
        state.consume(line("[Stop hook] Query completed for session \(a)"), at: now)
        state.consume(line("Received permission response for \(request): once (tool: Bash)"), at: now)
        #expect(state.sessions[a]?.status == .done)
        state.markViewed(a)
        #expect(state.sessions[a]?.status == .idle)
        state.consume(line("LocalSessions.archive: sessionId=\(a)"), at: now)
        #expect(state.sessions.isEmpty)
    }

    @Test func staleObservationsAndExpiry() {
        var state = ClaudeDesktopLogState()
        state.consume(line("LocalSessions.sendMessage: sessionId=\(a)"), at: now)
        state.prune(at: now.addingTimeInterval(1801))
        #expect(state.sessions[a]?.status == .unknown)
        state.prune(at: now.addingTimeInterval(86401))
        #expect(state.sessions.isEmpty)
    }

    @Test func incrementalReadsPartialLinesTruncationAndRotation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("main.log")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let prefix = formatter.string(from: now) + " [info] "
        let start = prefix + "Starting local session \(a) in /example/Test\n"
        try Data(start.utf8).write(to: url)
        let reader = ClaudeDesktopLogReader(url: url)
        let first = try await reader.read(at: now)
        #expect(first.count == 1)
        #expect(first.first?.status == .working)
        let append = try FileHandle(forWritingTo: url)
        try append.seekToEnd()
        try append.write(contentsOf: Data((prefix + "[Stop hook] Query completed for session \(a)").utf8))
        #expect(try await reader.read(at: now) == first)
        try append.write(contentsOf: Data("\n".utf8))
        try append.close()
        #expect(try await reader.read(at: now).first?.status == .done)
        // Same-inode truncation must clear both the cursor and old sessions.
        let truncate = try FileHandle(forWritingTo: url)
        try truncate.truncate(atOffset: 0)
        try truncate.close()
        #expect(try await reader.read(at: now).isEmpty)
        // Atomic replacement is a new inode, not an append.
        try Data((prefix + "LocalSessions.sendMessage: sessionId=\(b)\n").utf8)
            .write(to: url, options: .atomic)
        let rotated = try await reader.read(at: now)
        #expect(rotated.count == 1)
        #expect(rotated.first?.id == b)
        try FileManager.default.removeItem(at: url)
        await #expect(throws: (any Error).self) { try await reader.read(at: now) }
    }

    @Test @MainActor func desktopActionsCannotRouteToHerdr() {
        let model = NotchViewModel()
        let session = ClaudeDesktopSession(id: a, project: "Example", status: .blocked, updatedAt: now)
        #expect(session.attentionItem.ref.sessionID == "claude-desktop")
        #expect(session.attentionItem.summary == "Needs your input in Claude")
        #expect(model.registry.runtime(for: session.attentionItem.ref) == nil)
        #expect(model.selectedAgentSupportsModeCycling == false)
    }
    @Test func localLogSmokeWhenExplicitlyRequested() async throws {
        guard ProcessInfo.processInfo.environment["NOTCHAGENT_DESKTOP_SMOKE"] == "1" else { return }
        let sessions = try await ClaudeDesktopLogReader().read()
        #expect(!sessions.isEmpty)
        // Counts only: do not disclose project names, IDs, or private log lines.
        print("Desktop live-log smoke: \(sessions.count) sessions parsed")
    }

    @Test @MainActor func desktopApplicationIdentity() {
        #expect(ClaudeDesktopMonitor.bundleIdentifiers.contains("com.anthropic.claudefordesktop"))
        #expect(ClaudeDesktopMonitor.bundleIdentifiers.contains("com.anthropic.claude"))
    }

    @Test @MainActor func runningDesktopSmokeWhenExplicitlyRequested() async throws {
        guard ProcessInfo.processInfo.environment["NOTCHAGENT_DESKTOP_SMOKE"] == "1" else { return }
        let monitor = ClaudeDesktopMonitor()
        defer { monitor.stop() }
        monitor.start { _, _ in }
        for _ in 0..<50 {
            if !monitor.sessions.isEmpty { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!monitor.sessions.isEmpty, "Running Desktop detection and log parsing must both succeed")
        #expect(monitor.sessions.contains { $0.title != nil }, "Real Desktop titles must be resolved")
        print("Desktop monitor smoke: \(monitor.sessions.count) sessions visible")
    }

    @Test func sessionLinksAreExactAndRejectUntrustedActions() {
        let url = ClaudeDesktopNavigation.url(sessionID: a)
        #expect(url?.absoluteString == "claude://code/continue?session=\(a)")
        #expect(ClaudeDesktopNavigation.url(sessionID: "last") == nil)
        #expect(ClaudeDesktopNavigation.url(sessionID: a + "&q=do-something") == nil)
        #expect(ClaudeDesktopNavigation.url(sessionID: "../../other") == nil)
    }

    @Test func titlesRefreshAndArchivesAreHidden() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directory = root.appendingPathComponent(UUID().uuidString).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = directory.appendingPathComponent(a + ".json")
        func write(title: String, id: String, archived: Bool = false) throws {
            let data = try JSONSerialization.data(withJSONObject: [
                "sessionId": id, "title": title, "isArchived": archived,
                "unrelatedSecret": "synthetic-ignored-value"])
            try data.write(to: file, options: .atomic)
        }
        var reader = ClaudeDesktopMetadataReader(root: root)
        let session = ClaudeDesktopSession(id: a, project: "Project", status: .done, updatedAt: now)
        try write(title: "Fix login", id: a)
        #expect(reader.enrich([session], at: now).first?.displayTitle == "Fix login")
        try write(title: "Renamed chat", id: a)
        #expect(reader.enrich([session], at: now).first?.displayTitle == "Renamed chat")
        try write(title: "Wrong session", id: b)
        #expect(reader.enrich([session], at: now).first?.displayTitle == "Project")
        try write(title: "Archived chat", id: a, archived: true)
        #expect(reader.enrich([session], at: now).isEmpty)
        try Data("broken json".utf8).write(to: file)
        #expect(reader.enrich([session], at: now).first?.displayTitle == "Project")
    }

}
