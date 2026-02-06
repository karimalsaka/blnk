import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Namespace private var stepNamespace
    @State private var demoFilter: DemoFilter = .needsReview
    @State private var demoRowExpansions: [String: DemoRowExpansion] = [:]
    @State private var appeared = false
    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                stepHeader
                    .padding(.top, 40)
                    .padding(.bottom, 16)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 56)

                navigationFooter
                    .padding(.horizontal, 56)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
            }
        }
        .frame(width: 680, height: 640)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            switch viewModel.currentStep {
            case .welcome:
                welcomeStep
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            case .instructions:
                instructionsStep
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            case .tokenInput:
                tokenInputStep
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            case .validation:
                validationStep
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .scrollIndicators(.hidden)
    }

    private var stepHeader: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentStepIndex ? AppTheme.textPrimary : AppTheme.stroke)
                    .frame(width: 6, height: 6)
                    .scaleEffect(index == currentStepIndex ? 1.0 : 0.85)
                    .animation(.easeOut(duration: 0.2), value: currentStepIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStepIndex + 1) of \(steps.count)")
    }

    private var steps: [OnboardingStep] {
        [.welcome, .instructions, .tokenInput, .validation]
    }

    private var currentStepIndex: Int {
        steps.firstIndex { $0 == viewModel.currentStep } ?? 0
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        OnboardingStepView(
            title: "blnk",
            subtitle: "Your pull requests, always visible",
            heroImageName: "ghost-image-onboarding",
            heroAccessibilityLabel: "blnk"
        ) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    OnboardingBulletItem(text: "See reviews that need your attention")
                    OnboardingBulletItem(text: "Track CI status without context switching")
                    OnboardingBulletItem(text: "Filter by Inbox, To Review, and Drafts")
                }

                previewCard
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Instructions Step

    private var instructionsStep: some View {
        OnboardingStepView(
            title: "Connect GitHub",
            subtitle: "Create a Personal Access Token"
        ) {
            VStack(alignment: .leading, spacing: 20) {
                fineGrainedPATInstructions
                classicPATInstructions
                permissionsInline
            }
        }
    }

    private var permissionsInline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Required permissions")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 5, height: 5)
                    Text("Pull requests")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 5, height: 5)
                    Text("Commit statuses")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 5, height: 5)
                    Text("Contents")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private var classicPATInstructions: some View {
        OnboardingInstructionCard(
            title: "Classic token",
            subtitle: "Quickest setup",
            action: viewModel.openGitHubTokenSettings
        ) {
            VStack(alignment: .leading, spacing: 6) {
                InstructionStepView(number: 1, text: "Open Tokens (classic) in GitHub")
                InstructionStepView(number: 2, text: "Create token with repo scope")
                InstructionStepView(number: 3, text: "Copy the token")
            }
        }
    }

    private var fineGrainedPATInstructions: some View {
        OnboardingInstructionCard(
            title: "Fine-grained token",
            subtitle: "More control over permissions",
            tagText: "Recommended",
            tagTint: AppTheme.success,
            action: viewModel.openGitHubFineGrainedTokenSettings
        ) {
            VStack(alignment: .leading, spacing: 6) {
                InstructionStepView(number: 1, text: "Open Fine-grained tokens in GitHub")
                InstructionStepView(number: 2, text: "Create token and select repositories")
                InstructionStepView(number: 3, text: "Set permissions to Read-only:")

                VStack(alignment: .leading, spacing: 4) {
                    PermissionRow(name: "Pull requests")
                    PermissionRow(name: "Commit statuses")
                    PermissionRow(name: "Contents")
                    PermissionRow(name: "Metadata", note: "auto-enabled")
                }
                .padding(.leading, 24)

                InstructionStepView(number: 4, text: "Copy the token")
            }
        }
    }

    // MARK: - Token Input Step

    private var tokenInputStep: some View {
        OnboardingStepView(
            title: "Paste token",
            subtitle: "We'll verify permissions before saving"
        ) {
            TokenInputView(
                tokenInput: $viewModel.tokenInput,
                isValidating: viewModel.isValidating,
                onValidate: viewModel.validateToken
            )
        }
    }

    // MARK: - Validation Step

    private var validationStep: some View {
        OnboardingStepView(
            title: "Validating",
            subtitle: "Checking your token permissions"
        ) {
            if let result = viewModel.validationResult {
                VStack(spacing: 20) {
                    if result.allPermissionsGranted {
                        completionBanner
                    }
                    PermissionChecklistView(validationResult: result)

                    if !result.allPermissionsGranted && result.hasMinimumPermissions {
                        limitedFunctionalityExplanation
                    }
                }
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking permissions...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            }
        }
    }

    private var limitedFunctionalityExplanation: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.warning)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text("Limited functionality")
                    .font(.system(size: 13, weight: .medium))
                if viewModel.validationResult?.canReadCommitStatuses.status != .granted {
                    Text("CI/CD status won't be visible without commit status permission.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.warningSoft.opacity(0.5))
        )
    }

    // MARK: - Navigation Footer

    private var navigationFooter: some View {
        HStack {
            if viewModel.currentStep != .welcome {
                Button("Back") {
                    viewModel.goBack()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(AppSoftButtonStyle(tint: .secondary))
            }

            Spacer()

            footerButtons
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        switch viewModel.currentStep {
        case .welcome:
            Button("Connect GitHub") {
                viewModel.proceedToInstructions()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(AppPrimaryButtonStyle())

        case .instructions:
            Button("Paste Token") {
                viewModel.proceedToTokenInput()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(AppPrimaryButtonStyle())

        case .tokenInput:
            EmptyView()

        case .validation:
            validationFooterButtons
        }
    }

    @ViewBuilder
    private var validationFooterButtons: some View {
        if let result = viewModel.validationResult {
            if result.allPermissionsGranted {
                Button("Start Tracking") {
                    viewModel.saveTokenAndComplete()
                    onComplete()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(AppPrimaryButtonStyle())
            } else if result.hasMinimumPermissions {
                HStack(spacing: 12) {
                    Button("Fix Permissions") {
                        viewModel.goBack()
                    }
                    .buttonStyle(AppSoftButtonStyle(tint: AppTheme.warning))

                    Button("Continue Anyway") {
                        viewModel.continueWithLimitedPermissions()
                        onComplete()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                Button("Fix Permissions") {
                    viewModel.goBack()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        AppTheme.canvas
            .ignoresSafeArea()
    }
}

// MARK: - Welcome Preview

private enum DemoFilter: String, CaseIterable, Identifiable {
    case needsReview
    case approved
    case drafts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needsReview: return "Needs Review"
        case .approved: return "Approved"
        case .drafts: return "Drafts"
        }
    }

    var tint: Color {
        switch self {
        case .needsReview: return AppTheme.warning
        case .approved: return AppTheme.success
        case .drafts: return AppTheme.accent
        }
    }
}

private struct DemoRowExpansion: Equatable {
    var showComments = false
    var showThreads = false
}

extension OnboardingView {
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(DemoFilter.allCases) { filter in
                    demoFilterPill(for: filter)
                }
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(demoPullRequests) { pullRequest in
                    PRRowView(
                        pr: pullRequest,
                        permissionsState: demoPermissionsState,
                        currentUserLogin: demoCurrentUser,
                        activeFilter: .inbox,
                        showComments: demoCommentBinding(for: pullRequest.id),
                        showThreads: demoThreadBinding(for: pullRequest.id),
                        isInteractive: false
                    )
                }
            }
        }
        .padding(12)
        .frame(width: AppLayout.menuPopoverWidth)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
        )
        .onChange(of: demoFilter) { _ in
            demoRowExpansions = [:]
        }
    }

    private func demoFilterPill(for filter: DemoFilter) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                demoFilter = filter
            }
        } label: {
            Text(filter.title)
                .font(.system(size: 11, weight: demoFilter == filter ? .semibold : .regular))
                .foregroundColor(demoFilter == filter ? AppTheme.textPrimary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(demoFilter == filter ? AppTheme.elevatedSurface : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var demoPullRequests: [PullRequest] {
        demoPullRequests(for: demoFilter)
    }

    private func demoPullRequests(for filter: DemoFilter) -> [PullRequest] {
        switch filter {
        case .needsReview:
            return [
                makeDemoPullRequest(
                    id: 1,
                    title: "Tighten retry backoff logic",
                    repoFullName: "acme/payments-api",
                    number: 1842,
                    isDraft: false,
                    ciStatus: .pending,
                    reviewState: .pending,
                    recentComments: [
                        demoComment(id: "d1", author: "maria", body: "Should we cap max retries here?", minutesAgo: 210),
                        demoComment(id: "d2", author: "you", body: "Good call — I’ll add a guard.", minutesAgo: 95)
                    ],
                    reviewThreads: [
                        demoThread(
                            id: "t1",
                            comments: [
                                demoComment(id: "t1-1", author: "maria", body: "This loop looks tight — can we add a backoff cap?", minutesAgo: 320),
                                demoComment(id: "t1-2", author: "you", body: "Yep, adding a cap now.", minutesAgo: 180)
                            ]
                        )
                    ]
                ),
                makeDemoPullRequest(
                    id: 2,
                    title: "Fix flaky snapshot tests",
                    repoFullName: "acme/mobile-ui",
                    number: 922,
                    isDraft: false,
                    ciStatus: .failure,
                    failedChecks: [],
                    reviewState: .changesRequested,
                    recentComments: [
                        demoComment(id: "d3", author: "lee", body: "Seeing failures on iOS 17 again.", minutesAgo: 60)
                    ]
                ),
                makeDemoPullRequest(
                    id: 3,
                    title: "Add audit log filter",
                    repoFullName: "acme/admin-console",
                    number: 311,
                    isDraft: false,
                    ciStatus: .success,
                    reviewState: .pending
                )
            ]
        case .approved:
            return [
                makeDemoPullRequest(
                    id: 4,
                    title: "Ship onboarding polish",
                    repoFullName: "acme/prpulse-mac",
                    number: 77,
                    isDraft: false,
                    ciStatus: .success,
                    reviewState: .approved,
                    recentComments: [
                        demoComment(id: "d4", author: "sarah", body: "Looks crisp. Nice polish.", minutesAgo: 120)
                    ]
                ),
                makeDemoPullRequest(
                    id: 5,
                    title: "Upgrade GraphQL query",
                    repoFullName: "acme/dev-tools",
                    number: 412,
                    isDraft: false,
                    ciStatus: .success,
                    reviewState: .approved
                ),
                makeDemoPullRequest(
                    id: 6,
                    title: "Update CI cache key",
                    repoFullName: "acme/infra",
                    number: 28,
                    isDraft: false,
                    ciStatus: .success,
                    reviewState: .approved,
                    reviewThreads: [
                        demoThread(
                            id: "t2",
                            comments: [
                                demoComment(id: "t2-1", author: "sarah", body: "Looks solid. Nice cleanup.", minutesAgo: 200),
                                demoComment(id: "t2-2", author: "you", body: "Thanks! Merging after CI.", minutesAgo: 120)
                            ]
                        )
                    ]
                )
            ]
        case .drafts:
            return [
                makeDemoPullRequest(
                    id: 7,
                    title: "Refine reviewer hints",
                    repoFullName: "acme/prpulse-mac",
                    number: 63,
                    isDraft: true,
                    ciStatus: .pending,
                    reviewState: .unknown
                ),
                makeDemoPullRequest(
                    id: 8,
                    title: "Add search by label",
                    repoFullName: "acme/frontend",
                    number: 1203,
                    isDraft: true,
                    ciStatus: .pending,
                    reviewState: .unknown,
                    recentComments: [
                        demoComment(id: "d5", author: "jules", body: "Can this filter by multiple labels?", minutesAgo: 45)
                    ]
                ),
                makeDemoPullRequest(
                    id: 9,
                    title: "Streamline notifications",
                    repoFullName: "acme/core",
                    number: 506,
                    isDraft: true,
                    ciStatus: .unknown,
                    reviewState: .unknown
                )
            ]
        }
    }

    private func demoCount(for filter: DemoFilter) -> Int {
        demoPullRequests(for: filter).count
    }

    private var demoSummaryPill: some View {
        HStack(spacing: 4) {
            Image(systemName: demoSummaryIcon)
                .font(.system(size: 10))
                .foregroundColor(demoSummaryColor)
            Text(demoSummaryText)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(demoSummaryColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(demoSummaryColor.opacity(0.12))
        .cornerRadius(999)
    }

    private var demoSummaryText: String {
        switch demoFilter {
        case .needsReview: return "2 need attention"
        case .approved: return "All good"
        case .drafts: return "3 drafts"
        }
    }

    private var demoSummaryColor: Color {
        switch demoFilter {
        case .needsReview: return AppTheme.warning
        case .approved: return AppTheme.success
        case .drafts: return AppTheme.accent
        }
    }

    private var demoSummaryIcon: String {
        switch demoFilter {
        case .needsReview: return "clock.circle.fill"
        case .approved: return "checkmark.circle.fill"
        case .drafts: return "pencil.circle.fill"
        }
    }

    private var demoPermissionsState: PermissionsState {
        PermissionsState(
            canReadPullRequests: true,
            canReadCommitStatuses: true,
            canReadReviews: true,
            canReadComments: true
        )
    }

    private var demoCurrentUser: String? {
        "you"
    }

    private func makeDemoPullRequest(
        id: Int,
        title: String,
        repoFullName: String,
        number: Int,
        authorLogin: String? = nil,
        isDraft: Bool,
        ciStatus: CIStatus,
        failedChecks: [String] = [],
        reviewState: ReviewState,
        recentComments: [PRComment] = [],
        reviewThreads: [PRCommentThread] = []
    ) -> PullRequest {
        PullRequest(
            id: "\(repoFullName)#\(number)",
            number: number,
            title: title,
            repoFullName: repoFullName,
            authorLogin: authorLogin,
            htmlURL: URL(string: "https://github.com/\(repoFullName)/pull/\(number)")!,
            headSHA: "",
            updatedAt: Date(),
            commentCount: recentComments.count + reviewThreads.reduce(0) { $0 + $1.comments.count },
            isDraft: isDraft,
            ciStatus: ciStatus,
            failedChecks: failedChecks,
            reviewState: reviewState,
            recentComments: recentComments,
            reviewThreads: reviewThreads
        )
    }

    private func demoComment(id: String, author: String, body: String, minutesAgo: Double) -> PRComment {
        PRComment(
            id: id,
            author: author,
            body: body,
            createdAt: Date().addingTimeInterval(-(minutesAgo * 60)),
            url: URL(string: "https://github.com/\(author)")
        )
    }

    private func demoThread(id: String, comments: [PRComment]) -> PRCommentThread {
        PRCommentThread(id: id, comments: comments)
    }

    private func demoCommentBinding(for id: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { demoRowExpansions[id]?.showComments ?? false },
            set: { newValue in
                if newValue {
                    demoRowExpansions = [id: DemoRowExpansion(showComments: true, showThreads: false)]
                } else {
                    var updated = demoRowExpansions[id] ?? DemoRowExpansion()
                    updated.showComments = false
                    demoRowExpansions[id] = updated
                }
            }
        )
    }

    private func demoThreadBinding(for id: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { demoRowExpansions[id]?.showThreads ?? false },
            set: { newValue in
                if newValue {
                    demoRowExpansions = [id: DemoRowExpansion(showComments: false, showThreads: true)]
                } else {
                    var updated = demoRowExpansions[id] ?? DemoRowExpansion()
                    updated.showThreads = false
                    demoRowExpansions[id] = updated
                }
            }
        )
    }

    private var completionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.success)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Ready to go")
                    .font(.system(size: 13, weight: .medium))
                Text("Your PRs will sync automatically.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.successSoft.opacity(0.6))
        )
    }
}

// MARK: - Helper Views

struct InstructionStepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16, alignment: .trailing)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PermissionRow: View {
    let name: String
    var note: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 4, height: 4)
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if let note {
                Text("(\(note))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .preferredColorScheme(.dark)
    }
}
