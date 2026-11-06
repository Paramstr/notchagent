import Foundation
import SQLite3
import HerdrClient

/// Opens app-owned databases read-only. No hooks, writes, or subprocesses.
actor CodexDesktopReader {
    private let root: URL
    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")) { self.root = root }
    func read(at now: Date = Date()) throws -> [ClaudeDesktopSession] {
        let rows = try query(root.appendingPathComponent("state_5.sqlite"), sql:
            "SELECT id,COALESCE(NULLIF(name,''),title),cwd,updated_at FROM threads WHERE archived=0 AND source='vscode' AND updated_at > \(Int(now.timeIntervalSince1970)-86400) ORDER BY updated_at DESC LIMIT 30")
        let history = root.appendingPathComponent("thread_history_1.sqlite")
        return rows.compactMap { row in
            guard row.count == 4, UUID(uuidString: row[0]) != nil, let timestamp = Double(row[3]) else { return nil }
            let id = row[0]
            let turns = try? query(history, sql: "SELECT status FROM thread_turns WHERE thread_id=? ORDER BY rollout_ordinal DESC LIMIT 1", id: id)
            let messages = try? query(history, sql: "SELECT item_json FROM thread_items WHERE thread_id=? AND item_type='agentMessage' ORDER BY rollout_ordinal DESC LIMIT 1", id: id)
            let status: RollupStatus
            switch turns?.first?.first {
            case "inProgress": status = now.timeIntervalSince1970 - timestamp < 1800 ? .working : .unknown
            case "completed": status = .done
            case "interrupted", "failed": status = .idle
            default: status = .unknown
            }
            var session = ClaudeDesktopSession(id: id, project: URL(fileURLWithPath: row[2]).lastPathComponent,
                status: status, updatedAt: Date(timeIntervalSince1970: timestamp), title: row[1], app: .codex)
            if let json = messages?.first?.first, let data = json.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = object["text"] as? String { session.preview = AssistantPreview.excerpt(text) }
            return session
        }
    }
    private func query(_ url: URL, sql: String, id: String? = nil) throws -> [[String]] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 100)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw CocoaError(.fileReadCorruptFile) }
        defer { sqlite3_finalize(statement) }
        if let id { _ = id.withCString { sqlite3_bind_text(statement, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) } }
        var result: [[String]] = []
        var code = sqlite3_step(statement)
        while code == SQLITE_ROW {
            result.append((0..<sqlite3_column_count(statement)).map { index in
                sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
            })
            code = sqlite3_step(statement)
        }
        guard code == SQLITE_DONE else { throw CocoaError(.fileReadUnknown) }
        return result
    }
}
