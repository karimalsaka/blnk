import SwiftUI

struct CommentRow: View {
    let comment: PRComment
    let isSelf: Bool
    let showReply: Bool
    let replyURL: URL?
    @State private var isExpanded = false
    @State private var isHovered = false

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
                commentText

                if shouldShowMore {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Text(isExpanded ? "Show less" : "Show more")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.hoverOverlay.opacity(isHovered ? 1 : 0))
                )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? AppTheme.strokeStrong : AppTheme.stroke, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onTapGesture {
            // Consume tap so the parent card doesn't open the PR.
            if shouldShowMore {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }

    private var commentText: some View {
        Text(isExpanded ? fullText : comment.preview)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(isExpanded ? nil : 3)
    }

    private var fullText: String {
        comment.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowMore: Bool {
        !fullText.isEmpty && fullText != comment.preview
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
