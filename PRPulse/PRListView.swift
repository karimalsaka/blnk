import SwiftUI

struct PRListView: View {
    @ObservedObject var service: GitHubService
    @Binding var showingTokenSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.pull")
                        .foregroundStyle(.secondary)
                    Text("PR Pulse")
                        .font(.headline)
                }
                Spacer()

                if service.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(action: { service.fetch() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PRFilter.allCases) { filter in
                        FilterPill(
                            filter: filter,
                            isActive: service.activeFilter == filter,
                            count: countFor(filter)
                        ) {
                            service.activeFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            Divider()

            if let error = service.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }

            if service.filteredPullRequests.isEmpty && !service.isLoading && service.errorMessage == nil {
                VStack(spacing: 10) {
                    Image(systemName: service.activeFilter == .all ? "checkmark.circle" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 36))
                        .foregroundColor(service.activeFilter == .all ? .green : .secondary)
                    Text(service.activeFilter == .all ? "All clear!" : "No matches")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(service.activeFilter == .all ? "No open pull requests" : "No PRs match this filter")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let filtered = service.filteredPullRequests
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, pr in
                            PRRowView(pr: pr)
                            if index < filtered.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                }
                .frame(maxHeight: 420)
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
                Button("Settings…") {
                    showingTokenSheet = true
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 400)
        .background(.regularMaterial)
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
                    .font(.system(size: 9))
                Text(filter.rawValue)
                    .font(.caption2)
                    .fontWeight(isActive ? .semibold : .regular)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isActive ? .white : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
            .cornerRadius(6)
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
        if failingCount > 0 { return .red }
        if pendingCount > 0 { return .orange }
        return .green
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
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(summaryColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(summaryColor.opacity(0.1))
        .cornerRadius(5)
    }
}

struct PRRowView: View {
    let pr: PullRequest
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(pr.htmlURL)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Top line: repo + number + draft badge
                HStack(spacing: 4) {
                    Text(pr.repoName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    Text("#\(pr.number)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if pr.isDraft {
                        Text("DRAFT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
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
                        .foregroundColor(.red)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                    }
                }

                // Title
                Text(pr.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                // Status pills
                HStack(spacing: 8) {
                    // CI Status pill — only show if we have actual CI data
                    if pr.ciStatus != .unknown {
                        StatusPill(
                            icon: pr.ciStatus.icon,
                            text: pr.ciStatus.label,
                            color: ciColor(pr.ciStatus)
                        )
                    }

                    // Review State pill
                    StatusPill(
                        icon: pr.reviewState.icon,
                        text: pr.reviewState.label,
                        color: reviewColor(pr.reviewState)
                    )

                    // Comments
                    if pr.commentCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 9))
                            Text("\(pr.commentCount)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                // Failed checks detail — only real failures, no token warnings
                if !pr.failedChecks.isEmpty && pr.ciStatus == .failure {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(pr.failedChecks.filter { !$0.hasPrefix("⚠️") }, id: \.self) { name in
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red)
                                Text(name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(4)
                }

                // Recent comments
                if !pr.recentComments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(pr.recentComments) { comment in
                            HStack(alignment: .top, spacing: 4) {
                                Text(comment.author)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                                Text(comment.preview)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func ciColor(_ status: CIStatus) -> Color {
        switch status {
        case .success: return .green
        case .failure: return .red
        case .pending: return .orange
        case .unknown: return .gray
        }
    }

    private func reviewColor(_ state: ReviewState) -> Color {
        switch state {
        case .approved: return .green
        case .changesRequested: return .orange
        case .pending: return .yellow
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
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.08))
        .cornerRadius(4)
    }
}

struct TokenSettingsView: View {
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)? = nil
    @State private var token: String = ""
    @State private var saved = false
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            Text("GitHub Personal Access Token")
                .font(.headline)

            Text("Create a token at github.com/settings/tokens with the **repo** scope.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            SecureField("ghp_xxxxxxxxxxxx", text: $token)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack {
                Button("Cancel") {
                    onDismiss?()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    if TokenManager.shared.saveToken(token) {
                        saved = true
                        onSave()
                        onDismiss?()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(token.isEmpty)
            }

            if TokenManager.shared.hasToken {
                Button("Remove Saved Token", role: .destructive) {
                    TokenManager.shared.deleteToken()
                    token = ""
                }
                .font(.caption)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
