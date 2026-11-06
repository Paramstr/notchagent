import Foundation
import Darwin

/// Owns the cursor, bounded line buffer and parser off the main actor.
actor ClaudeDesktopLogReader {
    private(set) var replayedHistory = false
    private let url: URL
    private var inode: UInt64?
    private var offset: UInt64 = 0
    private var partial = Data()
    private var state = ClaudeDesktopLogState()
    private var metadata = ClaudeDesktopMetadataReader()
    private let maximumRead = 2 * 1024 * 1024
    private let formatter: DateFormatter

    init(url: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Claude/main.log")) {
        self.url = url
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.formatter = formatter
    }

    func read(at now: Date = Date()) throws -> [ClaudeDesktopSession] {
        replayedHistory = false
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(handle.fileDescriptor, &info) == 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        let size = UInt64(max(0, info.st_size))
        let newInode = UInt64(info.st_ino)
        var skipPartialFirstLine = false
        if inode != newInode || size < offset {
            // Rotation/truncation invalidates all pending request correlations.
            replayedHistory = true
            state = ClaudeDesktopLogState()
            partial = Data()
            offset = size > maximumRead ? size - UInt64(maximumRead) : 0
            skipPartialFirstLine = offset > 0
            inode = newInode
        } else if size - offset > maximumRead {
            // A burst larger than the bound may have dropped state transitions.
            replayedHistory = true
            state = ClaudeDesktopLogState()
            partial = Data()
            offset = size - UInt64(maximumRead)
            skipPartialFirstLine = true
        }
        try handle.seek(toOffset: offset)
        let bytes = try handle.read(upToCount: maximumRead) ?? Data()
        offset += UInt64(bytes.count)
        partial.append(bytes)
        while let newline = partial.firstIndex(of: 10) {
            let data = partial[..<newline]
            let line = String(decoding: data, as: UTF8.self)
            partial.removeSubrange(...newline)
            if skipPartialFirstLine { skipPartialFirstLine = false; continue }
            guard line.count >= 19,
                  let date = formatter.date(from: String(line.prefix(19))),
                  date <= now.addingTimeInterval(60),
                  now.timeIntervalSince(date) < 24 * 60 * 60 else { continue }
            state.consume(line, at: date)
        }
        if partial.count > 64 * 1024 { partial = Data() }
        state.prune(at: now)
        return metadata.enrich(Array(state.sessions.values), at: now).sorted {
            if $0.status.precedence != $1.status.precedence { return $0.status.precedence > $1.status.precedence }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }
    }

    func markViewed(_ id: String) { state.markViewed(id) }
}
