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
                Button { monitor.openClaude(sessionID: session.id) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(NotchPalette.status(session.status)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.displayTitle).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            Text(session.statusText).font(.system(size: 10))
                                .foregroundStyle(NotchPalette.secondaryText)
                            Text("\(session.project) · \(session.updatedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 9)).foregroundStyle(NotchPalette.tertiaryText)
                        }
                        Spacer()
                        Label("Open chat", systemImage: "arrow.up.forward")
                            .font(.system(size: 11)).foregroundStyle(NotchPalette.action)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(NotchPalette.elevated))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open chat: \(session.displayTitle)")
                .help("Open this conversation in Claude Desktop")
            }
            Text("Reply and approve in Claude Desktop. Status is inferred from local logs.")
                .font(.system(size: 9)).foregroundStyle(NotchPalette.tertiaryText)
        }
        if let message = monitor.message {
            Text(message).font(.caption).foregroundStyle(NotchPalette.secondaryText)
        }
    }
}
