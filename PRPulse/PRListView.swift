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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text("blnk")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            if !service.pullRequests.isEmpty {
                                HealthSummaryView(service: service)
                            }
                        }
                    }

                    Spacer()

                    Button(action: { service.fetch() }) {
                        HStack(spacing: 6) {
                            if service.isLoading {
                                AppInlineSpinner(tint: AppTheme.accent, size: 13, lineWidth: 2)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text("Refresh")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                    }
                    .buttonStyle(AppToolbarButtonStyle(tint: AppTheme.accent))
                    .opacity(service.isLoading ? 0.75 : 1)
                    .disabled(service.isLoading)
                    .help("Refresh")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

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

                VStack(spacing: 0) {
                    if service.filteredPullRequests.isEmpty && !service.isLoading && service.errorMessage == nil {
                        let isInbox = service.activeFilter == .inbox
                        VStack(spacing: 0) {
                            AppCard {
                                VStack(spacing: 10) {
                                    Image(systemName: isInbox ? "checkmark.circle" : "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 36))
                                        .foregroundColor(isInbox ? AppTheme.success : .secondary)
                                    Text(isInbox ? "All caught up" : "No matches")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    Text(isInbox ? "Nothing needs your attention" : "No PRs match this filter")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(18)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                let filtered = service.filteredPullRequests
                                ForEach(Array(filtered.enumerated()), id: \.element.rowIdentity) { _, pr in
                                    PRRowView(
                                        pr: pr,
                                        permissionsState: service.permissionsState,
                                        currentUserLogin: service.currentUserLogin,
                                        activeFilter: service.activeFilter,
                                        showComments: commentBinding(for: pr.id),
                                        showThreads: threadBinding(for: pr.id)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 14)
                        }
                        .scrollIndicators(.hidden)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    AppDivider()

                    // Footer
                    HStack(spacing: 12) {
                        if service.lastUpdated != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Updated \(service.lastUpdatedLabel)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                            .foregroundColor(AppTheme.muted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(AppTheme.stroke, lineWidth: 1)
                                    )
                            )
                        }
                        Spacer()
                        Button("Settings") {
                            showingTokenSheet = true
                        }
                        .buttonStyle(AppToolbarButtonStyle(tint: .secondary))

                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                        .buttonStyle(AppToolbarButtonStyle(tint: .secondary))
                        .keyboardShortcut("q", modifiers: .command)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? .primary : .secondary)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(isActive ? AppTheme.accent : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isActive ? AppTheme.accentSoft : AppTheme.elevatedSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isActive ? AppTheme.accent.opacity(0.24) : AppTheme.stroke, lineWidth: 1)
                                )
                        )
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
    @ObservedObject var service: GitHubService

    private var attentionCount: Int { service.attentionCount }
    private var toReviewCount: Int { service.count(for: .review) }
    private var pendingCount: Int { service.pullRequests.filter { $0.ciStatus == .pending || $0.reviewState == .pending }.count }

    private var summaryColor: Color {
        if toReviewCount > 0 { return AppTheme.warning }
        if attentionCount > 0 { return AppTheme.danger }
        if pendingCount > 0 { return AppTheme.info }
        return AppTheme.success
    }

    private var summaryIcon: String {
        if toReviewCount > 0 { return "eye.circle.fill" }
        if attentionCount > 0 { return "exclamationmark.circle.fill" }
        if pendingCount > 0 { return "clock.circle.fill" }
        return "checkmark.circle.fill"
    }

    private var summaryText: String {
        if toReviewCount > 0 { return "\(toReviewCount) to review" }
        if attentionCount > 0 { return attentionLabel(count: attentionCount) }
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
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(summaryColor.opacity(0.12))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(summaryColor.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func attentionLabel(count: Int) -> String {
        if count == 1 { return "1 needs attention" }
        return "\(count) need attention"
    }
}

struct PRListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PRListView(service: GitHubService.preview(), showingTokenSheet: .constant(false))
                .previewDisplayName("PR List")

            PRListView(
                service: {
                    let service = GitHubService.preview()
                    service.activeFilter = .review
                    return service
                }(),
                showingTokenSheet: .constant(false)
            )
            .previewDisplayName("PR List - To Review")
        }
        .preferredColorScheme(.dark)
        .frame(width: 420, height: 720)
        .padding(.horizontal)
    }
}
