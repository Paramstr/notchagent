import Foundation

struct AssistantPreview {
    private var cache: [URL: (Date, String?)] = [:]
    static func excerpt(_ text: String) -> String? {
        let clean = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !clean.isEmpty else { return nil }
        return clean.count > 240 ? "…" + String(clean.suffix(240)) : clean
    }
    mutating func claudeTranscript(_ url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isSymbolicLinkKey]),
              values.isSymbolicLink != true, let date = values.contentModificationDate else { return nil }
        if let previous = cache[url], previous.0 == date { return previous.1 }
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        guard let size = try? file.seekToEnd() else { return nil }
        try? file.seek(toOffset: size > 524288 ? size - 524288 : 0)
        let data = (try? file.read(upToCount: 524288)) ?? Data()
        var preview: String?
        for line in data.split(separator: 10).reversed() {
            guard let json = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { continue }
            let text = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined(separator: " ")
            if let excerpt = Self.excerpt(text) { preview = excerpt; break }
        }
        if cache.count > 100 { cache.removeAll() }
        cache[url] = (date, preview)
        return preview
    }
}
