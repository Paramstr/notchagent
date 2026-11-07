import Foundation
import HerdrClient
import Testing
@testable import NotchApp

@Suite("Brief completion alerts") @MainActor
struct CompletionAlertTests {
    private func item(_ id: String) -> InteractionAttentionDisplayModel {
        ClaudeDesktopSession(id: id, project: "Synthetic test", status: .done, updatedAt: Date()).attentionItem
    }

    @Test func defaultsOnAndPersistsToggle() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = Settings(defaults: defaults)
        #expect(settings.briefCompletionAlerts)
        settings.briefCompletionAlerts = false
        #expect(!Settings(defaults: defaults).briefCompletionAlerts)
    }

    @Test func queuesSingleCardsAndAutomaticallyCollapses() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.completed(item("one"))
        model.completed(item("two"))
        #expect(model.presentation == .completion)
        #expect(model.completionAlert?.ref.paneID == "one")
        try await Task.sleep(for: .milliseconds(1500))
        #expect(model.completionAlert?.ref.paneID == "two")
        try await Task.sleep(for: .milliseconds(1500))
        #expect(model.presentation == .compact)
        #expect(model.completionAlert == nil)
        #expect(model.recentCompletions.count == 2)
    }

    @Test func hoverPausesAndManualOverviewCancelsTimer() async throws {
        let model = NotchViewModel()
        defer { model.stop() }
        model.completed(item("one"))
        model.hoverCompletion(true)
        try await Task.sleep(for: .milliseconds(1500))
        #expect(model.presentation == .completion)
        model.hoverCompletion(false)
        model.showOverview()
        try await Task.sleep(for: .milliseconds(1500))
        #expect(model.presentation == .overview)
        model.completed(item("two"))
        #expect(model.presentation == .overview)
        #expect(model.completionAlert == nil)
    }
}
