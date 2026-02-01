import SwiftUI

struct CommentRow: View {
    let comment: PRComment
    let isSelf: Bool
    let showReply: Bool
    let replyURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill((isSelf ? AppTheme.info : AppTheme.accent).opacity(0.16))
                .frame(width: 18, height: 18)
                .overlay(
                    Text(isSelf ? "Y" : comment.author.prefix(1).uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(isSelf ? AppTheme.info : AppTheme.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isSelf ? "You" : comment.author)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelf ? AppTheme.info : AppTheme.accent)

                    Spacer()

                    Text(relativeTimestamp(comment.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(comment.preview)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                if showReply, let replyURL {
                    HStack {
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(replyURL)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("Reply")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentSoft)
                            .foregroundColor(AppTheme.accent)
                            .cornerRadius(999)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

private func relativeTimestamp(_ date: Date) -> String {
    let now = Date()
    let hours = now.timeIntervalSince(date) / 3600
    if hours <= 12 {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
