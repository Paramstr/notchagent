import Foundation

/// One strict activity horizon for all desktop providers, including cached cloud data.
enum DesktopActivityWindow {
    static let duration: TimeInterval = 6 * 60 * 60

    static func contains(_ date: Date, at now: Date = Date()) -> Bool {
        date <= now.addingTimeInterval(60) && now.timeIntervalSince(date) < duration
    }
}
