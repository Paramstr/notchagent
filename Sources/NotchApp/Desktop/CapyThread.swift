import Foundation
import HerdrClient

struct CapyThread: Decodable, Sendable {
    let id: String
    let title: String?
    let status: String
    let archived: Bool
    let updatedAt: String
    let lastActivityAt: String?
    let hasUnreads: Bool?
    let needsYou: Bool?
    let crewNeedsYou: Int?
    let ask: CapyAsk?

    func session(previous: ClaudeDesktopSession?, project: String) -> ClaudeDesktopSession? {
        guard !archived, status != "archived", DesktopApp.capy.chatURL(id) != nil else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rawDate = lastActivityAt ?? updatedAt
        var date = formatter.date(from: rawDate)
        if date == nil { formatter.formatOptions = [.withInternetDateTime]; date = formatter.date(from: rawDate) }
        guard let date else { return nil }
        let rollup: RollupStatus
        let note: String?
        if needsYou == true || (crewNeedsYou ?? 0) > 0 || ask != nil || status == "waiting" {
            rollup = .blocked; note = "Needs your input in Capy"
        } else if status == "failed" {
            rollup = .blocked; note = "Run failed — check Capy"
        } else if status == "working" {
            rollup = .working; note = nil
        } else if status == "idle" {
            rollup = previous?.status == .working || previous?.status == .blocked || previous?.status == .done || hasUnreads == true ? .done : .idle
            note = rollup == .idle ? "Idle" : nil
        } else { rollup = .unknown; note = nil }
        var result = ClaudeDesktopSession(id: id, project: project, status: rollup, updatedAt: date,
            title: title ?? "Capy thread", app: .capy, preview: ask?.text.flatMap(AssistantPreview.excerpt))
        result.statusOverride = note
        result.attentionRevision = rollup == .blocked ? ask?.key ?? status + updatedAt : nil
        return result
    }
}
