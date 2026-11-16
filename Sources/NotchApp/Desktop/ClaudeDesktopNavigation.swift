import Foundation

enum ClaudeDesktopNavigation {
    /// Same local Code continuation route used by Claude Desktop's Spotlight
    /// entries. Validate the complete ID so metadata cannot inject URL actions.
    static func url(sessionID: String) -> URL? {
        guard sessionID.hasPrefix("local_"), sessionID.count == 42,
              UUID(uuidString: String(sessionID.dropFirst(6))) != nil else { return nil }
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/continue"
        components.queryItems = [URLQueryItem(name: "session", value: sessionID)]
        return components.url
    }
}
