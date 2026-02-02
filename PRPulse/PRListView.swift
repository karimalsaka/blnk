import SwiftUI

struct PRListView: View {
    @ObservedObject var service: GitHubService
    @Binding var showingTokenSheet: Bool
    @State private var rowExpansions: [String: RowExpansion] = [:]

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Everything you need, before you blink")
                            .padding(.top, 10)
                            .font(.system(size: 14, weight: .semibold))
                        Text("Pull Requests")
                            .font(.system(size: 11, weight: .medium))
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
                            ForEach(Array(filtered.enumerated()), id: \.element.rowIdentity) { _, pr in
                                PRRowView(
                                    pr: pr,
                                    permissionsState: service.permissionsState,
                                    currentUserLogin: service.currentUserLogin,
                                    showComments: commentBinding(for: pr.id),
                                    showThreads: threadBinding(for: pr.id)
                                )
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
        .onChange(of: service.activeFilter) { _ in
            rowExpansions = [:]
        }
    }

    private func countFor(_ filter: PRFilter) -> Int {
        return service.count(for: filter)
    }

    private func commentBinding(for id: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { rowExpansions[id]?.showComments ?? false },
            set: { newValue in
                if newValue {
                    rowExpansions = [id: RowExpansion(showComments: true, showThreads: false)]
                } else {
                    var updated = rowExpansions[id] ?? RowExpansion()
                    updated.showComments = false
                    rowExpansions[id] = updated
                }
            }
        )
    }

    private func threadBinding(for id: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { rowExpansions[id]?.showThreads ?? false },
            set: { newValue in
                if newValue {
                    rowExpansions = [id: RowExpansion(showComments: false, showThreads: true)]
                } else {
                    var updated = rowExpansions[id] ?? RowExpansion()
                    updated.showThreads = false
                    rowExpansions[id] = updated
                }
            }
        )
    }
}

private struct RowExpansion: Equatable {
    var showComments = false
    var showThreads = false
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

#Preview("PR List") {
    PRListView(service: GitHubService.preview(), showingTokenSheet: .constant(false))
        .preferredColorScheme(.dark)
        .frame(width: 420, height: 720)
        .padding(.horizontal)

}
