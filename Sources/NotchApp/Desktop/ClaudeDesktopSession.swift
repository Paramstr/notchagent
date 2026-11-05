import Foundation
import HerdrClient

/// Read-only observations, never a target for Herdr's terminal commands.
struct ClaudeDesktopSession: Identifiable, Equatable, Sendable {
    let id: String
    var project: String
    var status: RollupStatus
    var updatedAt: Date

    static let notificationSessionID = "claude-desktop"

    var attentionItem: InteractionAttentionDisplayModel {
        InteractionAttentionDisplayModel(
            paneID: id, sessionID: Self.notificationSessionID,
            sessionLabel: "Claude Desktop", taskTitle: project, agentName: "Claude Desktop",
            workspaceLabel: project, tabTitle: "Desktop", status: status,
            state: nil, summaryOverride: statusText, isSelected: false)
    }

    var statusText: String {
        switch status {
        case .working: "Working"
        case .blocked: "Needs your input in Claude"
        case .done: "Finished"
        case .idle: "Viewed"
        case .unknown: "Status unconfirmed — open Claude"
        }
    }
}
