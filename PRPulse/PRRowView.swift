import SwiftUI

struct PRRowView: View {
    let pr: PullRequest
    let permissionsState: PermissionsState
    let currentUserLogin: String?
    let activeFilter: PRFilter
    let isInteractive: Bool
    @Binding var showComments: Bool
    @Binding var showThreads: Bool
    @State private var isHovered = false
    @State private var isDiscussionHovered = false
    @State private var isInlineHovered = false
    @State private var isCommentHovered = false
    private var displayCommentCount: Int { pr.allComments.count }
    private var singleThreadComments: [PRComment] {
        pr.reviewThreads
            .filter { $0.comments.count == 1 }
            .flatMap { $0.comments }
    }
    private var multiCommentThreads: [PRCommentThread] {
        pr.reviewThreads.filter { $0.comments.count > 1 }
    }
    private var discussionComments: [PRComment] {
        (pr.recentComments + singleThreadComments).sorted(by: { $0.createdAt < $1.createdAt })
    }
    private var authorPillText: String? {
        guard let author = pr.authorLogin, !author.isEmpty else { return nil }
        guard let current = currentUserLogin?.lowercased(), !current.isEmpty else { return author }
        return author.lowercased() == current ? "mine" : author
    }

    init(
        pr: PullRequest,
        permissionsState: PermissionsState,
        currentUserLogin: String?,
        activeFilter: PRFilter = .inbox,
        showComments: Binding<Bool> = .constant(false),
        showThreads: Binding<Bool> = .constant(false),
        isInteractive: Bool = true
    ) {
        self.pr = pr
        self.permissionsState = permissionsState
        self.currentUserLogin = currentUserLogin
        self.activeFilter = activeFilter
        self._showComments = showComments
        self._showThreads = showThreads
        self.isInteractive = isInteractive
    }

    var body: some View {
        let cornerRadius: CGFloat = 12
        let cardHoverActive = isHovered && !isDiscussionHovered && !isInlineHovered && !isCommentHovered
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.hoverOverlay.opacity(cardHoverActive ? 1 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(cardHoverActive ? AppTheme.strokeStrong : AppTheme.stroke, lineWidth: 1)
                )
                .shadow(color: AppTheme.cardShadow, radius: cardHoverActive ? 6 : 3, x: 0, y: cardHoverActive ? 3 : 2)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text(pr.repoName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                            Text("#\(pr.number)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppTheme.surface)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                        )

                        if let authorPillText {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(authorPillText)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppTheme.elevatedSurface)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(AppTheme.stroke, lineWidth: 1)
                                    )
                            )
                        }

                        if pr.isDraft {
                            Text("DRAFT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.10))
                                .cornerRadius(999)
                        }

                        Spacer()

                        if permissionsState.canReadComments && displayCommentCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 9))
                                Text("\(displayCommentCount)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                    }

                    Text(pr.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 8) {
                        if permissionsState.canReadCommitStatuses && pr.ciStatus != .unknown {
                            StatusPill(
                                icon: pr.ciStatus.icon,
                                text: ciSummaryText(),
                                color: ciColor(pr.ciStatus)
                            )
                        }

                        if permissionsState.canReadReviews {
                            StatusPill(
                                icon: pr.reviewState.icon,
                                text: pr.reviewState.label,
                                color: reviewColor(pr.reviewState)
                            )
                        }
                    }

                    let tags = reasonTags()
                    if !tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(tags.prefix(2)) { tag in
                                AppTag(text: tag.text, icon: tag.icon, tint: tag.tint)
                            }
                            if tags.count > 2 {
                                AppTag(text: "+\(tags.count - 2)", icon: nil, tint: .secondary)
                            }
                        }
                    }

                    if permissionsState.canReadCommitStatuses && !pr.failedChecks.isEmpty && pr.ciStatus == .failure {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Checks failing (\(pr.failedChecks.count))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(pr.failedChecks.filter { !$0.hasPrefix("⚠️") }, id: \.self) { name in
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(AppTheme.danger)
                                    Text(name)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(AppTheme.dangerSoft.opacity(0.6))
                        .cornerRadius(10)
                    }
                }
                .allowsHitTesting(false)

                if permissionsState.canReadComments && displayCommentCount > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        if !discussionComments.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: showComments ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(showComments ? AppTheme.accent : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Discussion")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Text(showComments ? "Hide comments" : "Show latest comments")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(discussionComments.count)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(showComments ? .white : AppTheme.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(showComments ? AppTheme.accent : AppTheme.accentSoft)
                                        .cornerRadius(999)
                                }
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(isDiscussionHovered ? AppTheme.strokeStrong : AppTheme.stroke, lineWidth: 1)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(AppTheme.hoverOverlay.opacity(isDiscussionHovered ? 1 : 0))
                                        )
                                )
                                .contentShape(Rectangle())
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isDiscussionHovered = hovering
                                        }
                                        if isInteractive {
                                            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                                        }
                                    }
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        showComments.toggle()
                                    }
                                }

                                    if showComments {
                                        let replyTargetId = discussionComments.last?.id
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(discussionComments) { comment in
                                                CommentRow(
                                                    comment: comment,
                                                    isSelf: isSelfComment(comment),
                                                    showReply: isInteractive && comment.id == replyTargetId && !isSelfComment(comment),
                                                    replyURL: comment.url
                                                )
                                            }
                                        }
                                        .onHover { hovering in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isCommentHovered = hovering
                                            }
                                        }
                                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showComments)
                        }

                        if !multiCommentThreads.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: showThreads ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(showThreads ? AppTheme.accent : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Inline Comments")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Text(showThreads ? "Hide inline threads" : "Show inline threads")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(multiCommentThreads.count)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(showThreads ? .white : AppTheme.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(showThreads ? AppTheme.accent : AppTheme.accentSoft)
                                        .cornerRadius(999)
                                }
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(isInlineHovered ? AppTheme.strokeStrong : AppTheme.stroke, lineWidth: 1)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(AppTheme.hoverOverlay.opacity(isInlineHovered ? 1 : 0))
                                        )
                                )
                                .contentShape(Rectangle())
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isInlineHovered = hovering
                                        }
                                        if isInteractive {
                                            if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                                        }
                                    }
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        showThreads.toggle()
                                    }
                                }

                                if showThreads {
                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(multiCommentThreads) { thread in
                                            threadView(thread)
                                        }
                                    }
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isCommentHovered = hovering
                                        }
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showThreads)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            guard isInteractive else { return }
            NSWorkspace.shared.open(pr.htmlURL)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if isInteractive {
                if hovering && !isDiscussionHovered && !isInlineHovered {
                    NSCursor.pointingHand.set()
                } else if !hovering {
                    NSCursor.arrow.set()
                }
            }
        }
    }

    private func ciColor(_ status: CIStatus) -> Color {
        switch status {
        case .success: return AppTheme.success
        case .failure: return AppTheme.danger
        case .pending: return AppTheme.warning
        case .unknown: return .gray
        }
    }

    private func ciSummaryText() -> String {
        switch pr.ciStatus {
        case .success:
            return "CI • Passing"
        case .failure:
            if pr.failedChecks.isEmpty {
                return "CI • Failed"
            }
            return "CI • \(pr.failedChecks.count) failed"
        case .pending:
            return "CI • Running"
        case .unknown:
            return "CI"
        }
    }

    private func reviewColor(_ state: ReviewState) -> Color {
        switch state {
        case .approved: return AppTheme.success
        case .changesRequested: return AppTheme.warning
        case .pending: return AppTheme.info
        case .unknown: return .gray
        }
    }

    private func isSelfComment(_ comment: PRComment) -> Bool {
        guard let login = currentUserLogin?.lowercased(), !login.isEmpty else { return false }
        return comment.author.lowercased() == login
    }

    private struct ReasonTag: Identifiable {
        let id: String
        let text: String
        let icon: String?
        let tint: Color
    }

    private func reasonTags() -> [ReasonTag] {
        func tag(_ text: String, _ icon: String?, _ tint: Color) -> ReasonTag {
            ReasonTag(id: text, text: text, icon: icon, tint: tint)
        }

        let hasFailureOrChangesRequested =
            (permissionsState.canReadCommitStatuses && pr.ciStatus == .failure) ||
            (permissionsState.canReadReviews && pr.reviewState == .changesRequested)

        let details: [ReasonTag] = [
            pr.hasConflicts ? tag("Conflicts", "exclamationmark.triangle.fill", AppTheme.danger) : nil,
        ].compactMap { $0 }

        let isToReview = pr.isRequestedReviewer && !pr.isReviewedByMe
        let reviewTag = tag("Needs your review", "eye.circle.fill", AppTheme.warning)

        func tagsForReview(details: [ReasonTag]) -> [ReasonTag] {
            var tags = details
            if pr.hasConflicts {
                tags.insert(reviewTag, at: min(1, tags.count))
            } else {
                tags.insert(reviewTag, at: 0)
            }
            return tags
        }

        switch activeFilter {
        case .inbox:
            if isToReview {
                return tagsForReview(details: details)
            }
            if !details.isEmpty {
                return details
            }
            if hasFailureOrChangesRequested {
                return []
            }
            return [tag("Needs attention", "exclamationmark.circle.fill", AppTheme.danger)]

        case .review:
            return tagsForReview(details: details)

        case .discussed:
            var tags: [ReasonTag] = []
            if pr.isReviewedByMe {
                tags.append(tag("You reviewed", "checkmark.seal.fill", AppTheme.success))
            }
            if hasMyCommentActivity() {
                tags.append(tag("You commented", "bubble.left.and.bubble.right.fill", AppTheme.accent))
            }
            return tags

        case .mine:
            return []

        case .drafts:
            return [tag("Draft", "doc.fill", .secondary)]
        }
    }

    private func hasMyCommentActivity() -> Bool {
        guard let loginLower = currentUserLogin?.lowercased(), !loginLower.isEmpty else { return false }
        if pr.hasMyComment { return true }
        return pr.allComments.contains { $0.author.lowercased() == loginLower }
    }

    private func threadView(_ thread: PRCommentThread) -> some View {
        let sortedComments = thread.comments.sorted(by: { $0.createdAt < $1.createdAt })
        let starter = sortedComments.first
        let latest = sortedComments.last
        let replyTargetId = latest?.id
        let starterLabel = starter.map { isSelfComment($0) ? "You started a thread" : "\($0.author) started a thread" } ?? "Thread"
        let latestLabel: String = {
            guard let latest = latest else { return "" }
            return isSelfComment(latest) ? "You replied most recently" : "\(latest.author) replied most recently"
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.accent)
                Text(starterLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if !latestLabel.isEmpty {
                    Text("• \(latestLabel)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(sortedComments) { comment in
                    CommentRow(
                        comment: comment,
                        isSelf: isSelfComment(comment),
                        showReply: isInteractive && comment.id == replyTargetId && !isSelfComment(comment),
                        replyURL: comment.url
                    )
                        .padding(.leading, 6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
        )
    }
}
