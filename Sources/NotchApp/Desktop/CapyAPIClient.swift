import Foundation

actor CapyAPIClient {
    private let session: URLSession
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }
    func read(key: String, extraIDs: [String], previous: [ClaudeDesktopSession]) async throws -> [ClaudeDesktopSession] {
        let projects: CapyAPIPage<CapyProject> = try await get("projects", key: key)
        var threads: [String: ClaudeDesktopSession] = [:]
        let old = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        for project in projects.items {
            var cursor: String?
            var pages = 0
            repeat {
                var query = [URLQueryItem(name: "projectId", value: project.id), URLQueryItem(name: "limit", value: "50")]
                if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
                let page: CapyAPIPage<CapyThread> = try await get("threads", query: query, key: key)
                for thread in page.items {
                    if let value = thread.session(previous: old[thread.id], project: project.name),
                       DesktopActivityWindow.contains(value.updatedAt) {
                        threads[value.id] = value
                    }
                }
                cursor = page.cursor
                pages += 1
                if cursor != nil && pages >= 100 { throw CapyAPIError.tooManyThreads }
            } while cursor != nil
        }
        for id in extraIDs where DesktopApp.capy.chatURL(id) != nil {
            let thread: CapyThread = try await get("threads/" + id, key: key)
            if let value = thread.session(previous: old[id], project: "Capy") { threads[id] = value }
        }
        return threads.values.filter { DesktopActivityWindow.contains($0.updatedAt) }.sorted { $0.updatedAt > $1.updatedAt }
    }
    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], key: String) async throws -> T {
        var url = URLComponents(string: "https://api.capy.ai/api/v1/" + path)!
        if !query.isEmpty { url.queryItems = query }
        var request = URLRequest(url: url.url!)
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CapyAPIError.unavailable }
        switch response.statusCode {
        case 200: break
        case 401, 403: throw CapyAPIError.access
        case 429: throw CapyAPIError.rateLimited
        default: throw CapyAPIError.unavailable
        }
        guard data.count <= 8 * 1024 * 1024 else { throw CapyAPIError.unavailable }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
