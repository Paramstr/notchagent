import SwiftUI

struct ElapsedActivityLabel: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.elapsed(since: since, at: context.date))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(NotchPalette.primaryText)
                Text("ago")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(NotchPalette.secondaryText)
            }
            .frame(minWidth: 58, alignment: .trailing)
            .fixedSize()
            .accessibilityLabel("Updated \(Self.elapsed(since: since, at: context.date)) ago")
        }
    }

    static func elapsed(since: Date, at now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(since)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}
