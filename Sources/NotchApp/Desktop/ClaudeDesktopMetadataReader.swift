import Foundation

/// Owned by the log-reader actor. Only account/org directories and the metadata
/// files of already-observed Code sessions are read. Cowork data is not searched.
struct ClaudeDesktopMetadataReader {
    let root: URL
    private var directories: [URL] = []
    private var previews = AssistantPreview()
    private var lastDiscovery: Date?

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions")) {
        self.root = root
    }

    mutating func enrich(_ sessions: [ClaudeDesktopSession], at now: Date) -> [ClaudeDesktopSession] {
        if lastDiscovery.map({ now.timeIntervalSince($0) >= 30 }) ?? true {
            directories = uuidDirectories(root).flatMap(uuidDirectories)
            lastDiscovery = now
        }
        return sessions.compactMap { session in
            guard ClaudeDesktopNavigation.url(sessionID: session.id) != nil else { return session }
            var result = session
            for directory in directories {
                let file = directory.appendingPathComponent(session.id + ".json")
                guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey]),
                      values.isSymbolicLink != true,
                      let size = values.fileSize, size <= 2 * 1024 * 1024,
                      let data = try? Data(contentsOf: file),
                      let metadata = try? JSONDecoder().decode(ClaudeDesktopMetadata.self, from: data),
                      metadata.sessionId == session.id else { continue }
                if metadata.isArchived == true { return nil }
                let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                result.title = title.flatMap { $0.isEmpty ? nil : String($0.prefix(500)) }
                if let cliID = metadata.cliSessionId, UUID(uuidString: cliID) != nil,
                   let cwd = metadata.cwd, cwd.hasPrefix("/") {
                    let project = cwd.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "-" }.joined()
                    let transcript = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".claude/projects").appendingPathComponent(project)
                        .appendingPathComponent(cliID + ".jsonl")
                    result.preview = previews.claudeTranscript(transcript)
                }
                break
            }
            return result
        }
    }

    private func uuidDirectories(_ directory: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])) ?? []
        return entries.filter {
            guard UUID(uuidString: $0.lastPathComponent) != nil,
                  let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
            return values.isDirectory == true && values.isSymbolicLink != true
        }.sorted { $0.path < $1.path }
    }
}
