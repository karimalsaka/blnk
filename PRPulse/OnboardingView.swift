import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Namespace private var stepNamespace
    @State private var demoFilter: DemoFilter = .needsReview
    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    stepHeader
                    stepContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                AppDivider()

                navigationFooter
                    .padding(20)
            }
        }
        .frame(width: 840, height: 760)
        .background(AppTheme.canvas)
        .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep)
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
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .instructions:
                instructionsStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .tokenInput:
                tokenInputStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .validation:
                validationStep
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .scrollIndicators(.hidden)
    }

    private var stepHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("blnk Setup")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(stepSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                AppTag(text: "Step \(currentStepIndex + 1) of \(steps.count)", icon: nil, tint: AppTheme.accent)
            }

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(index <= currentStepIndex ? AppTheme.accent : AppTheme.stroke.opacity(0.9))
                        .frame(width: index == currentStepIndex ? 64 : 36, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStepIndex)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.stroke.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private var steps: [OnboardingStep] {
        [.welcome, .instructions, .tokenInput, .validation]
    }

    private var currentStepIndex: Int {
        steps.firstIndex { $0 == viewModel.currentStep } ?? 0
    }

    private var stepSubtitle: String {
        switch viewModel.currentStep {
        case .welcome: return "A quick look before you connect GitHub"
        case .instructions: return "Create a token in under 2 minutes"
        case .tokenInput: return "Paste a token to start tracking"
        case .validation: return "Finishing setup and permissions"
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        OnboardingStepView(
            title: "Welcome to blnk",
            subtitle: "Monitor your GitHub pull requests from your menu bar"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    OnboardingBulletItem(text: "Spot reviews that need your attention fast")
                    OnboardingBulletItem(text: "Track build checks without opening GitHub")
                    OnboardingBulletItem(text: "Use Inbox, To Review, and Drafts filters")
                }
                .padding(.leading, 4)

                OnboardingPreviewSection(
                    title: "Your PR workspace",
                    subtitle: "A quick peek at the live list you’ll get"
                ) {
                    previewCard
                }
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Instructions Step

    private var instructionsStep: some View {
        OnboardingStepView(
            title: "Connect GitHub",
            subtitle: "Create a Personal Access Token and paste it next"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                permissionsInline
                fineGrainedPATInstructions
                classicPATInstructions
            }
        }
    }

    private var permissionsInline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text("Permissions required to use blnk")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    AppTag(text: "Required", icon: nil, tint: AppTheme.accent)
                    Text("Pull requests, Reviews, Comments (read-only)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    AppTag(text: "Optional", icon: nil, tint: .secondary)
                    Text("Commit statuses (read-only)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.accentSoft.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
        )
    }

    private var classicPATInstructions: some View {
        OnboardingInstructionCard(
            title: "Classic (quickest)",
            subtitle: "Broad scope, one checkbox",
            action: viewModel.openGitHubTokenSettings
        ) {
            VStack(alignment: .leading, spacing: 8) {
                InstructionStepView(number: 1, text: "Open Tokens (classic) in GitHub settings")
                InstructionStepView(number: 2, text: "Generate a token named 'blnk' with the repo scope")
                InstructionStepView(number: 3, text: "Generate and copy it (you won't see it again)")
            }
        }
    }

    private var fineGrainedPATInstructions: some View {
        OnboardingInstructionCard(
            title: "Fine-grained (recommended)",
            subtitle: "Scoped access with repo selection",
            tagText: "Recommended",
            tagTint: AppTheme.success,
            action: viewModel.openGitHubFineGrainedTokenSettings
        ) {
            VStack(alignment: .leading, spacing: 8) {
                InstructionStepView(number: 1, text: "Open Fine-grained tokens in GitHub settings")
                InstructionStepView(number: 2, text: "Generate a token named 'blnk' and choose repos")
                InstructionStepView(number: 3, text: "Set these permissions:")

                VStack(alignment: .leading, spacing: 4) {
                    PermissionInstructionView(name: "Pull requests", access: "Read-only")
                    PermissionInstructionView(name: "Commit statuses", access: "Read-only")
                    PermissionInstructionView(name: "Contents", access: "Read-only")
                    PermissionInstructionView(name: "Metadata", access: "Read-only (auto)")
                }
                .padding(.leading, 24)

                InstructionStepView(number: 4, text: "Generate and copy the token")
            }
        }
    }

    // MARK: - Token Input Step

    private var tokenInputStep: some View {
        OnboardingStepView(
            title: "Enter Your Token",
            subtitle: "Paste your token to start tracking"
        ) {
            VStack(spacing: 24) {
                TokenInputView(
                    tokenInput: $viewModel.tokenInput,
                    isValidating: viewModel.isValidating,
                    onValidate: viewModel.validateToken
                )

                Text("We validate permissions before saving anything.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Validation Step

    private var validationStep: some View {
        OnboardingStepView(
            title: "Token Validation",
            subtitle: "Checking permissions and wrapping up"
        ) {
            if let result = viewModel.validationResult {
                VStack(spacing: 24) {
                    if result.allPermissionsGranted {
                        completionBanner
                    }
                    PermissionChecklistView(validationResult: result)

                    if !result.allPermissionsGranted && result.hasMinimumPermissions {
                        limitedFunctionalityExplanation
                    }
                }
            } else {
                ProgressView("Validating token...")
            }
        }
    }

    private var limitedFunctionalityExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.warningSoft)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.warning)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("You’re still set")
                        .font(.headline)
                    Text("Some details will be hidden until permissions are added.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.validationResult?.canReadCommitStatuses.status != .granted {
                FeatureLimitationView(
                    feature: "CI/CD Status",
                    description: "You won't see build and test results"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
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

extension OnboardingView {
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Everything you need, before you blink")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("Pull Requests")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Refresh")
                    }
                }
                .buttonStyle(AppToolbarButtonStyle(tint: AppTheme.accent))
            }

            HStack(spacing: 8) {
                demoSummaryPill
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Updated just now")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
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

            HStack(spacing: 8) {
                ForEach(DemoFilter.allCases) { filter in
                    demoFilterPill(for: filter)
                }
            }

            VStack(spacing: 10) {
                ForEach(demoPullRequests) { pullRequest in
                    PRRowView(
                        pr: pullRequest,
                        permissionsState: demoPermissionsState,
                        currentUserLogin: demoCurrentUser,
                        activeFilter: .inbox,
                        isInteractive: false
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.stroke.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private func demoFilterPill(for filter: DemoFilter) -> some View {
        Button {
            demoFilter = filter
        } label: {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(demoFilter == filter ? .primary : .secondary)
                Text("\(demoCount(for: filter))")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(demoFilter == filter ? AppTheme.accent : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(demoFilter == filter ? AppTheme.accentSoft : AppTheme.elevatedSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(demoFilter == filter ? AppTheme.accent.opacity(0.24) : AppTheme.stroke, lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(demoFilter == filter ? AppTheme.surface : AppTheme.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(demoFilter == filter ? AppTheme.accent.opacity(0.4) : AppTheme.stroke, lineWidth: 1)
                    )
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
                    failedChecks: ["CI / snapshot-tests"],
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

    private var completionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(AppTheme.success)
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("You're set")
                    .font(.headline)
                Text("First sync starts now and updates every few minutes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.successSoft)
        )
    }
}

// MARK: - Helper Views

struct InstructionStepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.accent)
                .frame(width: 24, height: 24, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.accentSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(AppTheme.stroke, lineWidth: 1)
                        )
                )

            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PermissionInstructionView: View {
    let name: String
    let access: String

    var body: some View {
        HStack {
            Text("•")
                .foregroundColor(AppTheme.accent)
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("→")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(access)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.accent)
        }
    }
}

struct FeatureLimitationView: View {
    let feature: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppTheme.warning)
                .frame(width: 10, height: 10)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .preferredColorScheme(.dark)
    }
}
