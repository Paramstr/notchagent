import Foundation
import SQLite3
import Testing
@testable import NotchApp

@Suite("Desktop message previews")
struct DesktopPreviewTests {
    @Test func previewsExcludeToolsAndThinkingAndUseMessageTail() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let lines: [[String: Any]] = [
            ["type": "assistant", "message": ["content": [["type": "text", "text": "First reply"]]]],
            ["type": "assistant", "message": ["content": [["type": "text", "text": "Latest\nreply"], ["type": "thinking", "thinking": "private"]]]],
            ["type": "assistant", "message": ["content": [["type": "tool_use", "name": "secret tool"]]]],
            ["type": "user", "message": ["content": [["type": "text", "text": "User text"]]]]
        ]
        let data = try lines.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }.joined(separator: "\n")
        try Data(data.utf8).write(to: file)
        var reader = AssistantPreview()
        #expect(reader.claudeTranscript(file) == "Latest reply")
        #expect(AssistantPreview.excerpt(String(repeating: "a", count: 300) + "the end")?.hasSuffix("the end") == true)
        #expect(DesktopApp.codex.chatURL("../new?prompt=bad") == nil)
        let id = UUID().uuidString
        #expect(DesktopApp.codex.chatURL(id)?.absoluteString == "codex://threads/\(id)")
    }

    @Test func codexReadsOnlyRecentDesktopChatsAndLatestAssistantMessage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)
        func create(_ filename: String, _ sql: String) throws {
            var db: OpaquePointer?
            #expect(sqlite3_open(root.appendingPathComponent(filename).path, &db) == SQLITE_OK)
            defer { sqlite3_close(db) }
            #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        }
        try create("state_5.sqlite", """
            CREATE TABLE threads(id TEXT,title TEXT,cwd TEXT,updated_at INTEGER,archived INTEGER,source TEXT);
            INSERT INTO threads VALUES('\(id)','Example chat','/tmp/project',\(timestamp),0,'vscode');
            INSERT INTO threads VALUES('invalid','Hidden child','/tmp/project',\(timestamp),0,'subagent');
            INSERT INTO threads VALUES('\(UUID().uuidString)','Archived','/tmp/project',\(timestamp),1,'vscode');
            """)
        try create("thread_history_1.sqlite", """
            CREATE TABLE thread_turns(thread_id TEXT,status TEXT,rollout_ordinal INTEGER);
            CREATE TABLE thread_items(thread_id TEXT,item_type TEXT,item_json TEXT,rollout_ordinal INTEGER);
            INSERT INTO thread_turns VALUES('\(id)','inProgress',1);
            INSERT INTO thread_items VALUES('\(id)','agentMessage','{"text":"Latest assistant reply"}',2);
            INSERT INTO thread_items VALUES('\(id)','reasoning','{"text":"Do not show this"}',3);
            """)
        let sessions = try await CodexDesktopReader(root: root).read()
        #expect(sessions.count == 1)
        #expect(sessions.first?.app == .codex)
        #expect(sessions.first?.status == .working)
        #expect(sessions.first?.preview == "Latest assistant reply")
    }
}
