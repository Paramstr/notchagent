import SwiftUI

struct RecentCompletionGlow: ViewModifier {
    let completedAt: Date?
    func body(content: Content) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let age = completedAt.map { context.date.timeIntervalSince($0) } ?? 121
            let strength = age >= 0 && age < 120 ? min(1, (120 - age) / 15) : 0
            content.overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow.opacity(0.7 * strength), lineWidth: 1.5)
                    .shadow(color: .yellow.opacity(0.45 * strength), radius: 6)
                    .allowsHitTesting(false)
            }
        }
    }
}
