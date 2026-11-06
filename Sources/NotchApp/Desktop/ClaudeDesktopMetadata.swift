import Foundation

/// Decodes identity and presentation metadata only, never transcript contents.
struct ClaudeDesktopMetadata: Decodable, Sendable {
    let sessionId: String
    let title: String?
    let isArchived: Bool?
}
