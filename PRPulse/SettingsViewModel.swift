import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var tokenInput: String
    @Published var isValidating: Bool = false
    @Published var validationResult: TokenValidationService.TokenValidationResult?
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let tokenValidationService: TokenValidationService
    private let tokenManager: TokenManager

    init(
        tokenValidationService: TokenValidationService = TokenValidationService(),
        tokenManager: TokenManager = .shared
    ) {
        self.tokenValidationService = tokenValidationService
        self.tokenManager = tokenManager
        self.tokenInput = ""
    }

    var canValidateToken: Bool {
        !tokenInput.trimmingCharacters(in: .whitespaces).isEmpty && !isValidating
    }

    func validateToken() {
        guard canValidateToken else { return }
        let trimmedToken = tokenInput.trimmingCharacters(in: .whitespaces)

        Task {
            isValidating = true
            errorMessage = ""
            showError = false

            let result = await tokenValidationService.validateToken(trimmedToken)
            validationResult = result

            if !result.isValid {
                errorMessage = "Token validation failed. Please check your token and try again."
                showError = true
            }

            isValidating = false
        }
    }

    func saveToken() -> Bool {
        let trimmedToken = tokenInput.trimmingCharacters(in: .whitespaces)
        guard !trimmedToken.isEmpty else { return false }
        validationResult = nil
        return tokenManager.saveToken(trimmedToken)
    }

    func removeToken() {
        tokenManager.deleteToken()
        tokenInput = ""
        validationResult = nil
    }
}
