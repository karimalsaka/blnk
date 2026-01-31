import SwiftUI

struct PRListView: View {
    @ObservedObject var service: GitHubService
    @Binding var showingTokenSheet: Bool

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pull Requests")
                            .padding(.top, 10)
                            .font(.system(size: 19, weight: .semibold))
                        Text("Stay on top of reviews and checks")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if service.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 20, height: 20)
                            .padding(.trailing, 10)
                    } else {
                        Button(action: { service.fetch() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Refresh")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                        )
                        .help("Refresh")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Permissions Banner
                if !service.permissionsState.hasAllPermissions {
                    PermissionsBannerView(permissionsState: service.permissionsState)
                        .padding(.horizontal, 16)
                }

                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PRFilter.allCases) { filter in
                            FilterPill(
                                filter: filter,
                                isActive: service.activeFilter == filter,
                                count: countFor(filter)
                            ) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    service.activeFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }

                if let error = service.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.warning)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                }

                if service.filteredPullRequests.isEmpty && !service.isLoading && service.errorMessage == nil {
                    VStack(spacing: 0) {
                        AppCard {
                            VStack(spacing: 10) {
                                Image(systemName: service.activeFilter == .all ? "checkmark.circle" : "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 36))
                                    .foregroundColor(service.activeFilter == .all ? AppTheme.success : .secondary)
                                Text(service.activeFilter == .all ? "All clear!" : "No matches")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Text(service.activeFilter == .all ? "No open pull requests" : "No PRs match this filter")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(18)
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                    .frame(maxHeight: 650)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            let filtered = service.filteredPullRequests
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { _, pr in
                                PRRowView(pr: pr, permissionsState: service.permissionsState, currentUserLogin: service.currentUserLogin)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 650)
                }

                Divider()

                // Footer
                HStack(spacing: 12) {
                    if service.lastUpdated != nil {
                        Text("Updated \(service.lastUpdatedLabel)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Settings") {
                        showingTokenSheet = true
                    }
                    .buttonStyle(AppSoftButtonStyle(tint: .secondary))

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(AppSoftButtonStyle(tint: .secondary))
                    .keyboardShortcut("q", modifiers: .command)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                }
        }
        .frame(width: 450, height: 670)
        .background(AppTheme.canvas)
    }

    private func countFor(_ filter: PRFilter) -> Int {
        return service.count(for: filter)
    }
}

struct FilterPill: View {
    let filter: PRFilter
    let isActive: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(filter.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isActive ? .primary : .secondary)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                    
                        .foregroundColor(isActive ? AppTheme.accent : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AppTheme.canvas)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? AppTheme.surface : AppTheme.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isActive ? AppTheme.accent.opacity(0.4) : AppTheme.stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct HealthSummaryView: View {
    let pullRequests: [PullRequest]

    private var failingCount: Int { pullRequests.filter { $0.ciStatus == .failure || $0.hasConflicts }.count }
    private var pendingCount: Int { pullRequests.filter { $0.ciStatus == .pending || $0.reviewState == .pending }.count }
    private var goodCount: Int { pullRequests.filter { $0.ciStatus == .success && $0.reviewState == .approved }.count }
    private var needsReviewCount: Int { pullRequests.filter { $0.isRequestedReviewer }.count }

    private var summaryColor: Color {
        if failingCount > 0 { return AppTheme.danger }
        if pendingCount > 0 { return AppTheme.warning }
        return AppTheme.success
    }

    private var summaryIcon: String {
        if failingCount > 0 { return "exclamationmark.circle.fill" }
        if pendingCount > 0 { return "clock.circle.fill" }
        return "checkmark.circle.fill"
    }

    private var summaryText: String {
        if failingCount > 0 { return "\(failingCount) need attention" }
        if needsReviewCount > 0 { return "\(needsReviewCount) to review" }
        if pendingCount > 0 { return "\(pendingCount) pending" }
        return "All good"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: summaryIcon)
                .font(.system(size: 10))
                .foregroundColor(summaryColor)
            Text(summaryText)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(summaryColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(summaryColor.opacity(0.12))
        .cornerRadius(999)
    }
}

struct PRRowView: View {
    let pr: PullRequest
    let permissionsState: PermissionsState
    let currentUserLogin: String?
    @State private var isHovered = false
    @State private var isDiscussionHovered = false
    @State private var isInlineHovered = false
    @State private var showComments = false
    @State private var showThreads = false
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

    var body: some View {
        let cornerRadius: CGFloat = 12
        let cardHoverActive = isHovered && !isDiscussionHovered && !isInlineHovered
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.surface)
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
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppTheme.surface)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(AppTheme.stroke, lineWidth: 1)
                                    )
                            )
                            
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
                            
                            // Conflict badge (top-right, prominent)
                            if pr.hasConflicts {
                                HStack(spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9))
                                    Text("Conflicts")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(AppTheme.danger)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.dangerSoft)
                                .cornerRadius(999)
                            }
                        }

                        // Title
                        Text(pr.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(.primary)

                        // Status pills
                        HStack(spacing: 8) {
                            // CI Status pill — only show if we have permission and actual CI data
                            if permissionsState.canReadCommitStatuses && pr.ciStatus != .unknown {
                                StatusPill(
                                    icon: pr.ciStatus.icon,
                                    text: ciSummaryText(),
                                    color: ciColor(pr.ciStatus)
                                )
                            }

                            // Review State pill — only show if we have permission
                            if permissionsState.canReadReviews {
                                StatusPill(
                                    icon: pr.reviewState.icon,
                                    text: pr.reviewState.label,
                                    color: reviewColor(pr.reviewState)
                                )
                            }

                            // Comments — only show if we have permission
                            if permissionsState.canReadComments && displayCommentCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 9))
                                    Text("\(displayCommentCount)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.secondary)
                            }
                        }

                        // Failed checks detail — only show if we have permission and real failures
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

                    // Comments — only show if we have permission
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
                                    .foregroundColor(.primary)
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
                                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            showComments.toggle()
                                        }
                                    }

                                    if showComments {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(discussionComments) { comment in
                                                CommentRow(
                                                    comment: comment,
                                                    isSelf: isSelfComment(comment),
                                                    showReply: comment.id == discussionComments.last?.id && !isSelfComment(comment),
                                                    replyURL: comment.url
                                                )
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
                                    .foregroundColor(.primary)
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
                                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
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
            NSWorkspace.shared.open(pr.htmlURL)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering && !isDiscussionHovered && !isInlineHovered {
                NSCursor.pointingHand.push()
            } else if !hovering {
                NSCursor.pop()
            }
        }
    }

    private var statusAccent: Color {
        if pr.hasConflicts || pr.ciStatus == .failure { return AppTheme.danger }
        if pr.reviewState == .changesRequested { return AppTheme.warning }
        if pr.reviewState == .approved || pr.ciStatus == .success { return AppTheme.success }
        if pr.ciStatus == .pending { return AppTheme.warning }
        return AppTheme.accent.opacity(0.45)
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

    private func threadView(_ thread: PRCommentThread) -> some View {
        let sortedComments = thread.comments.sorted(by: { $0.createdAt < $1.createdAt })
        let starter = sortedComments.first
        let latest = sortedComments.last
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
                        showReply: comment.id == latest?.id && !isSelfComment(comment),
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

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .cornerRadius(999)
    }
}

#Preview("PR List") {
    PRListView(service: GitHubService.preview(), showingTokenSheet: .constant(false))
        .preferredColorScheme(.dark)
        .frame(width: 420, height: 720)
        .padding(.horizontal)

}
