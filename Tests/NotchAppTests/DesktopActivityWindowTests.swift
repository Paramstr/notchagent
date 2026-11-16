import Foundation
import Testing
@testable import NotchApp

@Suite("Desktop activity horizon")
struct DesktopActivityWindowTests {
    @Test func expiresAtSixHoursWithoutNewEvents() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let activity = now.addingTimeInterval(-6 * 3600 + 1)
        #expect(DesktopActivityWindow.contains(activity, at: now))
        #expect(!DesktopActivityWindow.contains(activity, at: now.addingTimeInterval(1)))
        #expect(!DesktopActivityWindow.contains(now.addingTimeInterval(-24 * 3600), at: now))
        #expect(!DesktopActivityWindow.contains(now.addingTimeInterval(3600), at: now))
    }
}
