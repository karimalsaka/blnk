import SwiftUI

struct TokenInputView: View {
    @Binding var tokenInput: String
    let isValidating: Bool
    let onValidate: () -> Void

    @FocusState private var isTokenFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            tokenInputField
            securityNote
        }
        .onAppear {
            isTokenFieldFocused = true
        }
    }

    // MARK: - Token Input Field

    private var tokenInputField: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $tokenInput)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .focused($isTokenFieldFocused)
                .onSubmit {
                    if !tokenInput.isEmpty {
                        onValidate()
                    }
                }
                .disabled(isValidating)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.stroke, lineWidth: 1)
                        )
                )

            Button(action: onValidate) {
                HStack(spacing: 8) {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Validating...")
                    } else {
                        Text("Validate")
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .opacity(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating ? 0.5 : 1)
            .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
        }
    }

    // MARK: - Security Note

    private var securityNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            Text("Your token is stored securely in macOS Keychain and only used to connect to GitHub.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

struct TokenInputView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TokenInputView(
                tokenInput: .constant(""),
                isValidating: false,
                onValidate: {}
            )
        }
        .frame(width: 500)
        .padding()
        .preferredColorScheme(.dark)
    }
}
