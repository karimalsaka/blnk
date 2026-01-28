import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    let onSave: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            header

                            AppCard {
                                VStack(alignment: .leading, spacing: 20) {
                                    tokenSection

                                    if let result = viewModel.validationResult {
                                        PermissionChecklistView(validationResult: result)
                                            .id("validation-results")
                                    }
                                }
                                .padding(24)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: viewModel.validationResult != nil) { isPresent in
                        guard isPresent else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("validation-results", anchor: .top)
                        }
                    }
                }

                Divider()

                footer
                    .padding(20)
            }
        }
        .frame(width: 600, height: 700)
        .background(AppTheme.canvas)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Token Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Replace and validate your GitHub token")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
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

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Remove Token", role: .destructive) {
                viewModel.removeToken()
            }
            .buttonStyle(AppSoftButtonStyle(tint: AppTheme.danger))

            Spacer()

            Button("Save") {
                if viewModel.saveToken() {
                    onSave()
                }
            }
            .buttonStyle(AppPrimaryButtonStrongStyle())
            .opacity(viewModel.tokenInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            .disabled(viewModel.tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Replace Token")
                    .font(.headline)
                Spacer()
                Button("Paste Saved") {
                    viewModel.tokenInput = TokenManager.shared.getToken() ?? ""
                }
                .buttonStyle(AppSoftButtonStyle(tint: .secondary))
            }

            TokenInputView(
                tokenInput: $viewModel.tokenInput,
                isValidating: viewModel.isValidating,
                onValidate: viewModel.validateToken
            )

            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption)
                    .foregroundColor(AppTheme.info)
                Text("Validate to preview permissions before saving.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview("Settings") {
    SettingsView(onSave: {})
        .preferredColorScheme(.dark)
}
