import SwiftUI

struct CompletionAlertView: View {
    @Bindable var model: NotchViewModel
    let topInset: CGFloat

    var body: some View {
        if let item = model.completionAlert {
            Button(action: model.openCompletion) {
                HStack(spacing: 12) {
                    if let session = model.desktop.sessions.first(where: { $0.attentionItem.ref == item.ref }),
                       let icon = session.app.icon {
                        Image(nsImage: icon).resizable().frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 25)).foregroundStyle(.yellow)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(item.agentName) finished").font(.system(size: 10, weight: .medium)).foregroundStyle(.yellow)
                        Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            .foregroundStyle(NotchPalette.primaryText)
                        if let preview = model.desktop.sessions.first(where: { $0.attentionItem.ref == item.ref })?.preview {
                            Text(preview).font(.system(size: 11)).lineLimit(2).truncationMode(.head)
                                .foregroundStyle(NotchPalette.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                    if let completedAt = model.recentCompletions[item.ref] {
                        ElapsedActivityLabel(since: completedAt)
                    }
                }
                .multilineTextAlignment(.leading)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(NotchPalette.elevated))
                .modifier(RecentCompletionGlow(completedAt: model.recentCompletions[item.ref]))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.title) finished. Open chat")
            .onHover(perform: model.hoverCompletion)
            .padding(.horizontal, 12)
            .padding(.top, topInset + 10)
        }
    }
}
