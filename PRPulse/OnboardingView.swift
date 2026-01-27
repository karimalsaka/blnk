import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    @Namespace private var stepNamespace

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

                Divider()

                // Navigation Footer
                navigationFooter
                    .padding(20)
            }
        }
        .frame(width: 640, height: 720)
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
                    Text("PRPulse Setup")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(stepSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                AppTag(text: "Step \(currentStepIndex + 1) of \(steps.count)", icon: "sparkles", tint: AppTheme.accent)
            }

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(index <= currentStepIndex ? AppTheme.accent : Color.secondary.opacity(0.2))
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
        case .welcome: return "Get oriented with what PRPulse does"
        case .instructions: return "Create your GitHub token in minutes"
        case .tokenInput: return "Paste and validate your token"
        case .validation: return "Review permission checks"
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        OnboardingStepView(
            title: "Welcome to PRPulse",
            subtitle: "Monitor your GitHub pull requests from your menu bar",
            iconName: "bolt.circle.fill",
            iconColor: .blue
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("PRPulse helps you stay on top of your pull requests with:")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 12) {
                    BulletPointView(text: "Real-time status updates every 5 minutes")
                    BulletPointView(text: "CI/CD check monitoring")
                    BulletPointView(text: "Review state tracking")
                    BulletPointView(text: "Recent comment notifications")
                    BulletPointView(text: "Filter by attention needed, approved, or drafts")
                }
                .padding(.leading, 8)

                Spacer()
                    .frame(height: 24)

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(AppTheme.success)
                    Text("Your data stays private - all communication is directly with GitHub")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.successSoft)
                )
            }
        }
    }

    // MARK: - Instructions Step

    private var instructionsStep: some View {
        OnboardingStepView(
            title: "Create a GitHub Token",
            subtitle: "PRPulse needs a Personal Access Token to access your pull requests",
            iconName: "key.fill",
            iconColor: .orange
        ) {
            VStack(alignment: .leading, spacing: 20) {
                // Token Type Selection
                tokenTypeSection

                Divider()

                // Classic PAT Instructions
                classicPATInstructions

                Divider()

                // Fine-grained PAT Instructions
                fineGrainedPATInstructions
            }
        }
    }

    private var tokenTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Your Token Type")
                .font(.headline)

            Text("GitHub offers two types of Personal Access Tokens:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                tokenTypeCard(
                    title: "Fine-grained (Recommended)",
                    description: "More secure with specific repository access",
                    iconName: "checkmark.shield.fill",
                    color: .green,
                    action: viewModel.openGitHubFineGrainedTokenSettings
                )

                tokenTypeCard(
                    title: "Classic",
                    description: "Simple but broader access scope",
                    iconName: "key.fill",
                    color: .orange,
                    action: viewModel.openGitHubTokenSettings
                )
            }
        }
    }

    private func tokenTypeCard(title: String, description: String, iconName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconName)
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    )
            )
            .shadow(color: color.opacity(0.12), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var classicPATInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Classic Token Setup")
                    .font(.headline)
                Spacer()
                Button("Open GitHub") {
                    viewModel.openGitHubTokenSettings()
                }
                .buttonStyle(.link)
            }

            VStack(alignment: .leading, spacing: 8) {
                InstructionStepView(number: 1, text: "Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)")
                InstructionStepView(number: 2, text: "Click 'Generate new token (classic)'")
                InstructionStepView(number: 3, text: "Give it a descriptive name like 'PRPulse'")
                InstructionStepView(number: 4, text: "Select the 'repo' scope (full control of private repositories)")
                InstructionStepView(number: 5, text: "Click 'Generate token' at the bottom")
                InstructionStepView(number: 6, text: "Copy the token (you won't see it again!)")
            }
        }
    }

    private var fineGrainedPATInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fine-grained Token Setup")
                    .font(.headline)
                Spacer()
                Button("Open GitHub") {
                    viewModel.openGitHubFineGrainedTokenSettings()
                }
                .buttonStyle(.link)
            }

            VStack(alignment: .leading, spacing: 8) {
                InstructionStepView(number: 1, text: "Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens")
                InstructionStepView(number: 2, text: "Click 'Generate new token'")
                InstructionStepView(number: 3, text: "Name it 'PRPulse' and set expiration")
                InstructionStepView(number: 4, text: "Choose repository access: 'All repositories' or select specific ones")
                InstructionStepView(number: 5, text: "Under 'Permissions' → 'Repository permissions', set:")

                VStack(alignment: .leading, spacing: 4) {
                    PermissionInstructionView(name: "Pull requests", access: "Read-only")
                    PermissionInstructionView(name: "Commit statuses", access: "Read-only")
                    PermissionInstructionView(name: "Contents", access: "Read-only")
                    PermissionInstructionView(name: "Metadata", access: "Read-only (auto)")
                }
                .padding(.leading, 24)

                InstructionStepView(number: 6, text: "Click 'Generate token' and copy it")
            }
        }
    }

    // MARK: - Token Input Step

    private var tokenInputStep: some View {
        OnboardingStepView(
            title: "Enter Your Token",
            subtitle: "Paste the Personal Access Token you just created",
            iconName: "lock.fill",
            iconColor: .green
        ) {
            VStack(spacing: 24) {
                TokenInputView(
                    tokenInput: $viewModel.tokenInput,
                    isValidating: viewModel.isValidating,
                    onValidate: viewModel.validateToken
                )

                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("The token will be validated to ensure it has the required permissions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Validation Step

    private var validationStep: some View {
        OnboardingStepView(
            title: "Token Validation",
            subtitle: "Checking permissions for your token",
            iconName: viewModel.validationResult?.allPermissionsGranted == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            iconColor: viewModel.validationResult?.allPermissionsGranted == true ? AppTheme.success : AppTheme.warning
        ) {
            if let result = viewModel.validationResult {
                VStack(spacing: 24) {
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
            Text("Everything Still Works")
                .font(.headline)

            Text("You can keep using PRPulse — the missing permission just hides the related details:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if viewModel.validationResult?.canReadCommitStatuses.status != .granted {
                FeatureLimitationView(
                    iconName: "xmark.circle.fill",
                    feature: "CI/CD Status",
                    description: "You won't see build and test results"
                )
            }

            if viewModel.validationResult?.canReadReviews.status != .granted {
                FeatureLimitationView(
                    iconName: "xmark.circle.fill",
                    feature: "Review States",
                    description: "You won't see approval or change request status"
                )
            }

            if viewModel.validationResult?.canReadComments.status != .granted {
                FeatureLimitationView(
                    iconName: "xmark.circle.fill",
                    feature: "Comments",
                    description: "You won't see recent PR comments"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.warningSoft)
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
            Button("Get Started") {
                viewModel.proceedToInstructions()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(AppPrimaryButtonStyle())

        case .instructions:
            Button("I Have My Token") {
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
                Button("Complete Setup") {
                    viewModel.saveTokenAndComplete()
                    dismiss()
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
                        dismiss()
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

// MARK: - Helper Views

struct InstructionStepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 24, height: 24)
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accent)
            }
            .frame(width: 24)

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
    let iconName: String
    let feature: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(AppTheme.warning)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
