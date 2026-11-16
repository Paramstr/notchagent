import Foundation
import Observation

@Observable @MainActor
final class CapyMonitor {
    private(set) var sessions: [ClaudeDesktopSession] = []
    private(set) var message = "Connect Capy in Settings to receive its alerts."
    private(set) var connected = false
    private(set) var generation = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let client = CapyAPIClient()

    func start() {
        guard task == nil, let key = CapyCredentialStore.load() else { return }
        task = Task { [weak self] in
            var baseline = false
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let links = UserDefaults.standard.string(forKey: "capyThreadLinks") ?? ""
                    let ids = links.split(whereSeparator: { $0.isWhitespace || $0 == "," }).compactMap { value -> String? in
                        let raw = String(value)
                        let id = URL(string: raw)?.lastPathComponent ?? raw
                        return DesktopApp.capy.chatURL(id) != nil ? id : nil
                    }
                    let next = try await client.read(key: key, extraIDs: Array(Set(ids)), previous: sessions)
                    guard !Task.isCancelled else { return }
                    if !baseline { generation += 1; baseline = true }
                    sessions = next
                    connected = true
                    message = "Connected · \(next.count) Capy chats · checks every 15 seconds"
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    guard !Task.isCancelled else { return }
                    connected = false
                    baseline = false
                    sessions = []
                    message = (error as? CapyAPIError)?.localizedDescription ?? "Cannot read Capy updates. Retrying in one minute."
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                }
            }
        }
    }
    func stop() {
        task?.cancel(); task = nil; sessions = []; connected = false; generation += 1
    }
    func reconnect() { stop(); start() }
    func disconnect() throws {
        try CapyCredentialStore.remove()
        stop()
        message = "Capy disconnected."
    }
}
