import Foundation
import HerdrClient

/// Parses only known metadata messages. Prompts, tool arguments and arbitrary
/// log content are neither retained nor published. Unknown events are ignored.
struct ClaudeDesktopLogState: Sendable {
    private(set) var sessions: [String: ClaudeDesktopSession] = [:]
    private var permissions: [String: String] = [:]

    mutating func consume(_ line: String, at date: Date) {
        guard let marker = line.range(of: " [info] ") else { return }
        let message = String(line[marker.upperBound...])
        let session = capture(#"local_[0-9a-fA-F-]{36}(?![0-9a-zA-Z:-])"#, in: message)
        if message.hasPrefix("Received permission response for "),
           let request = capture(#"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"#, in: message),
           let id = permissions.removeValue(forKey: request) {
            update(id, status: permissions.values.contains(id) ? .blocked : .working, date: date)
            return
        }
        guard let id = session else { return }
        if message.hasPrefix("LocalSessions.archive:") || message.hasPrefix("Archived session ") {
            sessions[id] = nil
            permissions = permissions.filter { $0.value != id }
        } else if message.hasPrefix("Starting local session ") {
            let project = message.range(of: " in /").map {
                (String(message[message.index($0.lowerBound, offsetBy: 4)...]) as NSString).lastPathComponent
            } ?? "Claude Desktop"
            update(id, status: .working, date: date, project: project)
        } else if message.hasPrefix("LocalSessions.sendMessage:") {
            update(id, status: .working, date: date)
        } else if message.hasPrefix("Emitted tool permission request "),
                  let request = capture(#"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"#, in: message) {
            permissions[request] = id
            update(id, status: .blocked, date: date)
        } else if message.hasPrefix("[Stop hook] Query completed for session ") {
            update(id, status: .done, date: date)
            permissions = permissions.filter { $0.value != id }
        }
    }

    mutating func markViewed(_ id: String) {
        guard sessions[id]?.status == .done else { return }
        sessions[id]?.status = .idle
    }

    mutating func prune(at now: Date) {
        sessions = sessions.filter { now.timeIntervalSince($0.value.updatedAt) < 24 * 60 * 60 }
        permissions = permissions.filter { sessions[$0.value] != nil }
        // Logs have no heartbeat. Never assert that an old observation is live.
        for id in Array(sessions.keys) {
            if let session = sessions[id], now.timeIntervalSince(session.updatedAt) > 30 * 60,
               session.status == .working || session.status == .blocked {
                sessions[id]?.status = .unknown
            }
        }
        if sessions.count > 100 {
            let keep = Set(sessions.values.sorted { $0.updatedAt > $1.updatedAt }.prefix(100).map(\.id))
            sessions = sessions.filter { keep.contains($0.key) }
            permissions = permissions.filter { keep.contains($0.value) }
        }
    }

    private mutating func update(_ id: String, status: RollupStatus, date: Date, project: String? = nil) {
        guard sessions[id].map({ $0.updatedAt <= date }) ?? true else { return }
        sessions[id] = ClaudeDesktopSession(
            id: id, project: project ?? sessions[id]?.project ?? "Claude Desktop",
            status: status, updatedAt: date)
    }

    private func capture(_ pattern: String, in text: String) -> String? {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range])
    }
}
