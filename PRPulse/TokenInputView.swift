import SwiftUI

struct TokenInputView: View {
    @Binding var tokenInput: String
    let isValidating: Bool
    let onValidate: () -> Void

    @FocusState private var isTokenFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            tokenInputField
            securityNote
        }
        .onAppear {
            isTokenFieldFocused = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter Your GitHub Token")
                .font(.headline)

            Text("Paste your Personal Access Token below")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Token Input Field

    private var tokenInputField: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $tokenInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isTokenFieldFocused)
                    .onSubmit {
                        if !tokenInput.isEmpty {
                            onValidate()
                        }
                    }
                    .disabled(isValidating)

                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.elevatedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.stroke.opacity(0.6), lineWidth: 1)
                    )
            )

            Button(action: onValidate) {
                HStack {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Validating...")
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Validate Token")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(AppPrimaryButtonStrongStyle())
            .opacity(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating ? 0.6 : 1)
            .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
        }
    }

    // MARK: - Security Note

    private var securityNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.caption)
                .foregroundColor(AppTheme.accent)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your token is stored securely")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("PRPulse stores your token locally and never sends it to any third-party servers. It's only used to communicate directly with GitHub's API.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.accentSoft)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        TokenInputView(
            tokenInput: .constant(""),
            isValidating: false,
            onValidate: {}
        )

        Divider()
            .padding(.vertical)

        TokenInputView(
            tokenInput: .constant("ghp_1234567890"),
            isValidating: true,
            onValidate: {}
        )
    }
    .frame(width: 500)
    .padding()
}
