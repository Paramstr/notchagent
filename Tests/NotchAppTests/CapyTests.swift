import Foundation
import HerdrClient
import Testing
@testable import NotchApp

@Suite("Capy status adapter")
struct CapyTests {
    let id = "jam_01M7GMT0288WWRJPYZRGCRXEM6"

    private func thread(_ fields: [String: Any]) throws -> CapyThread {
        var json: [String: Any] = ["id": id, "title": "Synthetic Capy task", "status": "idle", "archived": false,
            "updatedAt": "2026-11-15T22:38:18.248Z", "hasUnreads": false]
        json.merge(fields) { _, new in new }
        return try JSONDecoder().decode(CapyThread.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test func humanAndCrewRequestsOverrideWorking() throws {
        let ask: [String: Any] = ["key": "synthetic-request", "kind": "conversation", "text": "Please approve the plan"]
        let value = try thread(["status": "working", "needsYou": true, "ask": ask]).session(previous: nil, project: "Example")
        #expect(value?.status == .blocked)
        #expect(value?.preview == "Please approve the plan")
        #expect(value?.attentionRevision == "synthetic-request")
        #expect(try thread(["status": "working", "crewNeedsYou": 1]).session(previous: nil, project: "Example")?.status == .blocked)
    }

    @Test func completionRequiresEvidenceAndUnknownIsNotDone() throws {
        let working = try thread(["status": "working"]).session(previous: nil, project: "Example")
        #expect(try thread([:]).session(previous: nil, project: "Example")?.status == .idle)
        #expect(try thread([:]).session(previous: working, project: "Example")?.status == .done)
        #expect(try thread(["hasUnreads": true]).session(previous: nil, project: "Example")?.status == .done)
        #expect(try thread(["status": "future-state"]).session(previous: working, project: "Example")?.status == .unknown)
        #expect(try thread(["archived": true]).session(previous: working, project: "Example") == nil)
        #expect(try thread(["updatedAt": "not a date"]).session(previous: nil, project: "Example") == nil)
    }

    @Test func errorsNeedAttentionAndLinksCannotInjectActions() throws {
        let failed = try thread(["status": "failed"]).session(previous: nil, project: "Example")
        #expect(failed?.status == .blocked)
        #expect(failed?.statusText == "Run failed — check Capy")
        #expect(DesktopApp.capy.chatURL(id)?.absoluteString == "capy://app/thread/" + id)
        #expect(DesktopApp.capy.chatURL(id + "?prompt=do-something") == nil)
        #expect(DesktopApp.capy.chatURL("../../settings") == nil)
    }
}
