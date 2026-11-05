import HerdrClient
import SwiftUI

struct ClaudeDesktopSection: View {
    @Bindable var monitor: ClaudeDesktopMonitor

    var body: some View {
        if !monitor.sessions.isEmpty {
            Text("Claude Desktop")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchPalette.secondaryText)
            ForEach(monitor.sessions) { session in
                HStack(spacing: 10) {
                    Circle().fill(NotchPalette.status(session.status)).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.project).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Text(session.statusText).font(.system(size: 10))
                            .foregroundStyle(NotchPalette.secondaryText)
                        Text("Session \(session.id.suffix(8)) · \(session.updatedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9)).foregroundStyle(NotchPalette.tertiaryText)
                    }
                    Spacer()
                    Button("Open Claude") { monitor.openClaude(sessionID: session.id) }
                        .buttonStyle(.plain).foregroundStyle(NotchPalette.action)
                        .help("Opens Claude Desktop. Choose this session there to reply or approve.")
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 9).fill(NotchPalette.elevated))
            }
            Text("Reply and approve in Claude Desktop. Status is inferred from local logs.")
                .font(.system(size: 9)).foregroundStyle(NotchPalette.tertiaryText)
        }
        if let message = monitor.message {
            Text(message).font(.caption).foregroundStyle(NotchPalette.secondaryText)
        }
    }
}
