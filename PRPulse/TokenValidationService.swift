import Foundation

final class TokenValidationService: ObservableObject {
    @Published var isValidating = false
    @Published var validationResult: TokenValidationResult?

    private let graphQLURL = URL(string: "https://api.github.com/graphql")!

    enum PermissionStatus {
        case granted
        case denied
        case unknown

        var icon: String {
            switch self {
            case .granted: return "✅"
            case .denied: return "❌"
            case .unknown: return "⚠️"
            }
        }

        var label: String {
            switch self {
            case .granted: return "Access granted"
            case .denied: return "Missing permission"
            case .unknown: return "Unable to verify"
            }
        }
    }

    struct PermissionCheck {
        let name: String
        let description: String
        let status: PermissionStatus
        let errorMessage: String?
        let requiredScope: String?
    }

    struct TokenValidationResult {
        let isValid: Bool
        let canReadPullRequests: PermissionCheck
        let canReadCommitStatuses: PermissionCheck
        let canReadReviews: PermissionCheck
        let canReadComments: PermissionCheck
        let viewer: String?

        var allPermissionsGranted: Bool {
            canReadPullRequests.status == .granted &&
            canReadCommitStatuses.status == .granted &&
            canReadReviews.status == .granted &&
            canReadComments.status == .granted
        }

        var hasMinimumPermissions: Bool {
            canReadPullRequests.status == .granted &&
            canReadReviews.status == .granted &&
            canReadComments.status == .granted
        }

        var permissions: [PermissionCheck] {
            [canReadPullRequests, canReadCommitStatuses, canReadReviews, canReadComments]
        }
    }

    @MainActor
    func validateToken(_ token: String) async -> TokenValidationResult {
        isValidating = true

        // Test 1: Can we read pull requests and get viewer info?
        let prCheck = await testPullRequestsAccess(token: token)

        // Test 2: Can we read commit statuses?
        let statusCheck = await testCommitStatusAccess(token: token)

        // Test 3: Can we read reviews?
        let reviewCheck = await testReviewsAccess(token: token)

        // Test 4: Can we read comments?
        let commentCheck = await testCommentsAccess(token: token)

        let result = TokenValidationResult(
            isValid: prCheck.status == .granted,
            canReadPullRequests: prCheck,
            canReadCommitStatuses: statusCheck,
            canReadReviews: reviewCheck,
            canReadComments: commentCheck,
            viewer: prCheck.status == .granted ? "user" : nil
        )

        validationResult = result
        isValidating = false

        return result
    }

    // MARK: - Individual Permission Tests

    private func testPullRequestsAccess(token: String) async -> PermissionCheck {
        let query = """
        {
          viewer {
            login
            pullRequests(first: 1, states: OPEN) {
              totalCount
            }
          }
        }
        """

        let result = await executeQuery(query: query, token: token)

        switch result {
        case .success(let data):
            // Check if we got viewer data
            if let viewer = data["viewer"] as? [String: Any],
               let _ = viewer["login"] as? String {
                return PermissionCheck(
                    name: "Pull Requests",
                    description: "View your open pull requests",
                    status: .granted,
                    errorMessage: nil,
                    requiredScope: nil
                )
            }
            return PermissionCheck(
                name: "Pull Requests",
                description: "View your open pull requests",
                status: .denied,
                errorMessage: "Unable to read pull requests",
                requiredScope: "repo or public_repo"
            )

        case .failure(let error):
            return PermissionCheck(
                name: "Pull Requests",
                description: "View your open pull requests",
                status: .denied,
                errorMessage: error.localizedDescription,
                requiredScope: "repo or public_repo"
            )
        }
    }

    private func testCommitStatusAccess(token: String) async -> PermissionCheck {
        let query = """
        {
          viewer {
            pullRequests(first: 1, states: OPEN) {
              nodes {
                commits(last: 1) {
                  nodes {
                    commit {
                      statusCheckRollup {
                        state
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """

        let result = await executeQuery(query: query, token: token)

        switch result {
        case .success(let data):
            // If we can query statusCheckRollup without error, we have access
            if let viewer = data["viewer"] as? [String: Any],
               let prs = viewer["pullRequests"] as? [String: Any],
               let _ = prs["nodes"] as? [[String: Any]] {
                return PermissionCheck(
                    name: "CI/CD Status",
                    description: "View commit status checks and CI results",
                    status: .granted,
                    errorMessage: nil,
                    requiredScope: nil
                )
            }
            return PermissionCheck(
                name: "CI/CD Status",
                description: "View commit status checks and CI results",
                status: .unknown,
                errorMessage: "Unable to verify commit status access",
                requiredScope: "repo:status"
            )

        case .failure(let error):
            // If query fails, we might still have basic PR access but not status access
            let errorMessage = error.localizedDescription
            if errorMessage.contains("statusCheckRollup") {
                return PermissionCheck(
                    name: "CI/CD Status",
                    description: "View commit status checks and CI results",
                    status: .denied,
                    errorMessage: "Missing commit status permission",
                    requiredScope: "repo:status"
                )
            }
            return PermissionCheck(
                name: "CI/CD Status",
                description: "View commit status checks and CI results",
                status: .unknown,
                errorMessage: errorMessage,
                requiredScope: "repo:status"
            )
        }
    }

    private func testReviewsAccess(token: String) async -> PermissionCheck {
        let query = """
        {
          viewer {
            pullRequests(first: 1, states: OPEN) {
              nodes {
                reviews(last: 1) {
                  nodes {
                    state
                  }
                }
              }
            }
          }
        }
        """

        let result = await executeQuery(query: query, token: token)

        switch result {
        case .success(let data):
            if let viewer = data["viewer"] as? [String: Any],
               let prs = viewer["pullRequests"] as? [String: Any],
               let _ = prs["nodes"] as? [[String: Any]] {
                return PermissionCheck(
                    name: "Reviews",
                    description: "View PR review states and approvals",
                    status: .granted,
                    errorMessage: nil,
                    requiredScope: nil
                )
            }
            return PermissionCheck(
                name: "Reviews",
                description: "View PR review states and approvals",
                status: .unknown,
                errorMessage: "Unable to verify review access",
                requiredScope: "repo"
            )

        case .failure(let error):
            return PermissionCheck(
                name: "Reviews",
                description: "View PR review states and approvals",
                status: .denied,
                errorMessage: error.localizedDescription,
                requiredScope: "repo"
            )
        }
    }

    private func testCommentsAccess(token: String) async -> PermissionCheck {
        let query = """
        {
          viewer {
            pullRequests(first: 1, states: OPEN) {
              nodes {
                comments(last: 1) {
                  totalCount
                  nodes {
                    body
                  }
                }
              }
            }
          }
        }
        """

        let result = await executeQuery(query: query, token: token)

        switch result {
        case .success(let data):
            if let viewer = data["viewer"] as? [String: Any],
               let prs = viewer["pullRequests"] as? [String: Any],
               let _ = prs["nodes"] as? [[String: Any]] {
                return PermissionCheck(
                    name: "Comments",
                    description: "View PR comments and discussions",
                    status: .granted,
                    errorMessage: nil,
                    requiredScope: nil
                )
            }
            return PermissionCheck(
                name: "Comments",
                description: "View PR comments and discussions",
                status: .unknown,
                errorMessage: "Unable to verify comments access",
                requiredScope: "repo"
            )

        case .failure(let error):
            return PermissionCheck(
                name: "Comments",
                description: "View PR comments and discussions",
                status: .denied,
                errorMessage: error.localizedDescription,
                requiredScope: "repo"
            )
        }
    }

    // MARK: - GraphQL Execution

    enum ValidationError: Error {
        case message(String)

        var localizedDescription: String {
            switch self {
            case .message(let text):
                return text
            }
        }
    }

    private func executeQuery(query: String, token: String) async -> Result<[String: Any], ValidationError> {
        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = ["query": query]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.message("Failed to encode query"))
        }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.message("Invalid response"))
            }

            // Check for HTTP errors
            if httpResponse.statusCode == 401 {
                return .failure(.message("Invalid or expired token"))
            }

            if httpResponse.statusCode == 403 {
                return .failure(.message("Token lacks required permissions"))
            }

            if httpResponse.statusCode != 200 {
                return .failure(.message("HTTP \(httpResponse.statusCode)"))
            }

            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(.message("Invalid JSON response"))
            }

            // Check for GraphQL errors
            if let errors = json["errors"] as? [[String: Any]],
               let firstError = errors.first,
               let message = firstError["message"] as? String {
                return .failure(.message(message))
            }

            // Return data object
            if let dataObj = json["data"] as? [String: Any] {
                return .success(dataObj)
            }

            return .failure(.message("No data in response"))

        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }
}
