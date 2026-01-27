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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.pull")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                            Text("PRPulse")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        Text("Your pull request radar")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if service.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 20, height: 20)
                    } else {
                        Button(action: { service.fetch() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(8)
                        }
                        .buttonStyle(.borderless)
                        .help("Refresh")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                // Permissions Banner
                if !service.permissionsState.hasAllPermissions {
                    PermissionsBannerView(permissionsState: service.permissionsState)
                        .padding(.horizontal, 14)
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }

                if let error = service.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.warning)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                }

                if service.filteredPullRequests.isEmpty && !service.isLoading && service.errorMessage == nil {
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
                    .padding(.horizontal, 14)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            let filtered = service.filteredPullRequests
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { _, pr in
                                PRRowView(pr: pr, permissionsState: service.permissionsState)
                            }
                        }
                        .padding(.horizontal, 14)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                }
        }
        .frame(width: 450, height: 670)
        .background(AppTheme.canvas)
    }

    private func countFor(_ filter: PRFilter) -> Int {
        let prs = service.pullRequests
        switch filter {
        case .all: return prs.count
        case .needsAttention: return prs.filter { $0.ciStatus == .failure || $0.hasConflicts || $0.reviewState == .changesRequested }.count
        case .approved: return prs.filter { $0.reviewState == .approved }.count
        case .drafts: return prs.filter { $0.isDraft }.count
        }
    }
}

struct FilterPill: View {
    let filter: PRFilter
    let isActive: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(filter.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .fontWeight(isActive ? .semibold : .regular)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .white : AppTheme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isActive ? AppTheme.accent : AppTheme.accentSoft)
                        .cornerRadius(6)
                }
            }
            .foregroundColor(isActive ? AppTheme.accent : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? AppTheme.accentSoft : AppTheme.surface)
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
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(pr.htmlURL)
        }) {
            let cornerRadius: CGFloat = 16
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppTheme.stroke.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.04), radius: 8, x: 0, y: 4)

                Rectangle()
                    .fill(statusAccent)
                    .frame(width: 4)
                    .cornerRadius(2)
                    .padding(.vertical, cornerRadius)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 8) {
                    // Top line: repo + number + draft badge
                    HStack(spacing: 6) {
                        Text(pr.repoName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.accent)
                        Text("#\(pr.number)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if pr.isDraft {
                            Text("DRAFT")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                        }
                        Spacer()
                        // Conflict badge (top-right, prominent)
                        if pr.hasConflicts {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                Text("Conflicts")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(AppTheme.danger)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.dangerSoft)
                            .cornerRadius(6)
                    }
                    }

                    // Title
                    Text(pr.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    // Status pills
                    HStack(spacing: 8) {
                        // CI Status pill — only show if we have permission and actual CI data
                        if permissionsState.canReadCommitStatuses && pr.ciStatus != .unknown {
                            StatusPill(
                                icon: pr.ciStatus.icon,
                                text: pr.ciStatus.label,
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
                        if permissionsState.canReadComments && pr.commentCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 9))
                                Text("\(pr.commentCount)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                        }
                    }

                    // Failed checks detail — only show if we have permission and real failures
                    if permissionsState.canReadCommitStatuses && !pr.failedChecks.isEmpty && pr.ciStatus == .failure {
                        VStack(alignment: .leading, spacing: 3) {
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
                        .padding(.vertical, 6)
                        .background(AppTheme.dangerSoft.opacity(0.6))
                        .cornerRadius(8)
                    }

                    // Recent comments — only show if we have permission
                    if permissionsState.canReadComments && !pr.recentComments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(pr.recentComments) { comment in
                                HStack(alignment: .top, spacing: 4) {
                                    Text(comment.author)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.accent)
                                    Text(comment.preview)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
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

    private func reviewColor(_ state: ReviewState) -> Color {
        switch state {
        case .approved: return AppTheme.success
        case .changesRequested: return AppTheme.warning
        case .pending: return AppTheme.info
        case .unknown: return .gray
        }
    }
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }
}

#Preview("PR List") {
    PRListView(service: GitHubService.preview(), showingTokenSheet: .constant(false))
        .preferredColorScheme(.dark)
        .frame(width: 420, height: 720)
        .padding(.horizontal)

}
