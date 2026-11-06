import HerdrClient
import SwiftUI

struct ClaudeDesktopSection: View {
    @Bindable var monitor: ClaudeDesktopMonitor

    var body: some View {
        if !monitor.sessions.isEmpty {
            Text("Desktop chats")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchPalette.secondaryText)
            ForEach(monitor.sessions) { session in
                Button { monitor.openClaude(sessionID: session.id) } label: {
                    HStack(spacing: 10) {
                        VStack(spacing: 5) {
                            if let icon = session.app.icon {
                                Image(nsImage: icon)
                                    .resizable().frame(width: 24, height: 24)
                                    .accessibilityLabel(session.app.name)
                            } else {
                                Image(systemName: "bubble.left.and.bubble.right").frame(width: 24, height: 24)
                            }
                            Circle().fill(NotchPalette.status(session.status)).frame(width: 6, height: 6)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.displayTitle).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            Text("\(session.app.name) · \(session.statusText)").font(.system(size: 10))
                                .foregroundStyle(NotchPalette.secondaryText)
                            if let preview = session.preview {
                                Text(preview).font(.system(size: 10)).lineLimit(2).truncationMode(.head)
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(NotchPalette.secondaryText)
                            }
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
                .help("Open this conversation in \(session.app.name)")
            }
            Text("Reply and approve in the original app. Status and previews are read locally.")
                .font(.system(size: 9)).foregroundStyle(NotchPalette.tertiaryText)
        }
        if let message = monitor.message {
            Text(message).font(.caption).foregroundStyle(NotchPalette.secondaryText)
        }
    }
}
