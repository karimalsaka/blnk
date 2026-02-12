import SwiftUI

struct PRListView: View {
    @ObservedObject var service: GitHubService
    @Binding var showingTokenSheet: Bool
    @State private var rowExpansions: [String: RowExpansion] = [:]

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        // Logo + Status
                        HStack(spacing: 10) {
                            Image("ghost-image")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                                .frame(width: 44, height: 44)

                            if !service.pullRequests.isEmpty {
                                HealthSummaryView(service: service)
                            }
                        }

                        Spacer()

                        // Refresh button
                        Button(action: { service.fetch(force: true) }) {
                            HStack(spacing: 5) {
                                if service.isLoading {
                                    AppInlineSpinner(tint: AppTheme.accent, size: 12, lineWidth: 1.5)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                Text("Refresh")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                        .buttonStyle(RefreshButtonStyle())
                        .opacity(service.isLoading ? 0.7 : 1)
                        .disabled(service.isLoading)
                        .help("Refresh")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Permissions Banner
                if !service.permissionsState.hasAllPermissions {
                    PermissionsBannerView(permissionsState: service.permissionsState)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }

                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(PRFilter.allCases) { filter in
                            FilterPill(
                                filter: filter,
                                isActive: service.activeFilter == filter,
                                count: countFor(filter)
                            ) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    service.activeFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 1)
                }
                .padding(.bottom, 12)

                if let error = service.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.warning)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                // Content area
                VStack(spacing: 0) {
                    if service.filteredPullRequests.isEmpty && !service.isLoading && service.errorMessage == nil {
                        let isInbox = service.activeFilter == .inbox
                        VStack(spacing: 0) {
                            Spacer()

                            VStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(isInbox ? AppTheme.successSoft : AppTheme.surface)
                                        .frame(width: 64, height: 64)

                                    Image(systemName: isInbox ? "checkmark.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundColor(isInbox ? AppTheme.success : .secondary)
                                }

                                VStack(spacing: 4) {
                                    Text(isInbox ? "All caught up" : "No matches")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.textPrimary)

                                    Text(isInbox ? "Nothing needs your attention" : "No PRs match this filter")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 40)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(service.filteredPullRequests, id: \.rowIdentity) { pr in
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
                            .padding(.horizontal, 20)
                            .padding(.top, 2)
                            .padding(.bottom, 16)
                        }
                        .scrollIndicators(.hidden)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Subtle divider
                    Rectangle()
                        .fill(AppTheme.stroke)
                        .frame(height: 1)

                    // Footer
                    HStack(spacing: 10) {
                        if service.lastUpdated != nil {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(AppTheme.success.opacity(0.8))
                                    .frame(width: 5, height: 5)
                                Text("Updated \(service.lastUpdatedLabel)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: { showingTokenSheet = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(FooterIconButtonStyle())
                        .help("Settings")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: AppLayout.menuPopoverWidth, height: AppLayout.menuPopoverHeight)
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
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(filter.rawValue)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? AppTheme.textPrimary : .secondary)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(isActive ? AppTheme.accent : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isActive ? AppTheme.accentSoft : AppTheme.surface)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? AppTheme.elevatedSurface : (isHovered ? AppTheme.surface : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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
        if toReviewCount > 0 { return "eye.fill" }
        if attentionCount > 0 { return "exclamationmark.circle.fill" }
        if pendingCount > 0 { return "clock.fill" }
        return "checkmark.circle.fill"
    }

    private var summaryText: String {
        if toReviewCount > 0 { return "\(toReviewCount) to review" }
        if attentionCount > 0 { return attentionLabel(count: attentionCount) }
        if pendingCount > 0 { return "\(pendingCount) pending" }
        return "All good"
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(summaryColor)
                .frame(width: 6, height: 6)

            Text(summaryText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(summaryColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(summaryColor.opacity(0.1))
        )
    }

    private func attentionLabel(count: Int) -> String {
        if count == 1 { return "1 needs attention" }
        return "\(count) need attention"
    }
}

// MARK: - Button Styles

private struct RefreshButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppTheme.accent.opacity(configuration.isPressed ? 0.7 : 0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.accentSoft.opacity(configuration.isPressed ? 0.8 : 0.6))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct FooterIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary.opacity(configuration.isPressed ? 0.5 : 0.8))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.surface.opacity(configuration.isPressed ? 1 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// MARK: - Previews

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
        .frame(width: AppLayout.menuPopoverWidth, height: AppLayout.menuPopoverHeight)
        .padding(.horizontal)
    }
}
