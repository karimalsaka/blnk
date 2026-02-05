import Foundation

@MainActor
final class GitHubService: ObservableObject {
    @Published var pullRequests: [PullRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var activeFilter: PRFilter = .inbox
    @Published var useMockData = false
    @Published var permissionsState = PermissionsState()
    @Published var currentUserLogin: String?

    var filteredPullRequests: [PullRequest] {
        return pullRequests(for: activeFilter)
    }

    var attentionCount: Int {
        guard let viewerLoginLower = currentUserLogin?.lowercased(), !viewerLoginLower.isEmpty else { return 0 }
        return pullRequests.filter { pr in
            isMine(pr, viewerLoginLower: viewerLoginLower) && needsAttention(pr)
        }.count
    }

    func pullRequests(for filter: PRFilter) -> [PullRequest] {
        let viewerLoginLower = currentUserLogin?.lowercased()
        switch filter {
        case .inbox:
            return pullRequests.filter { pr in
                let toReview = pr.isRequestedReviewer && !pr.isReviewedByMe
                guard let viewerLoginLower else { return toReview }
                let mineNeedsAttention = isMine(pr, viewerLoginLower: viewerLoginLower) && needsAttention(pr)
                return toReview || mineNeedsAttention
            }
        case .review:
            return pullRequests.filter { $0.isRequestedReviewer && !$0.isReviewedByMe }
        case .discussed:
            guard let viewerLoginLower, !viewerLoginLower.isEmpty else { return [] }
            return pullRequests.filter { pr in
                let toReview = pr.isRequestedReviewer && !pr.isReviewedByMe
                if toReview { return false }
                return pr.isReviewedByMe || pr.hasMyComment
            }
        case .mine:
            guard let viewerLoginLower, !viewerLoginLower.isEmpty else { return [] }
            return pullRequests.filter { pr in
                isMine(pr, viewerLoginLower: viewerLoginLower) && !pr.isDraft
            }
        case .drafts:
            guard let viewerLoginLower, !viewerLoginLower.isEmpty else { return [] }
            return pullRequests.filter { pr in
                isMine(pr, viewerLoginLower: viewerLoginLower) && pr.isDraft
            }
        }
    }

    func count(for filter: PRFilter) -> Int {
        return pullRequests(for: filter).count
    }

    private var timer: Timer?
    private let pollInterval: TimeInterval = 300
    private let graphQLURL = URL(string: "https://api.github.com/graphql")!
    private let decoder = JSONDecoder()
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    var lastUpdatedLabel: String {
        guard let date = lastUpdated else { return "" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }

    var overallHealth: CIStatus {
        if pullRequests.isEmpty { return .unknown }
        if pullRequests.contains(where: { $0.ciStatus == .failure || $0.hasConflicts || $0.reviewState == .changesRequested }) {
            return .failure
        }
        if pullRequests.contains(where: { $0.ciStatus == .pending }) {
            return .pending
        }
        if pullRequests.allSatisfy({ $0.ciStatus == .success && $0.reviewState == .approved }) {
            return .success
        }
        return .pending
    }

    func startPolling() {
        fetch()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetch()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func fetch() {
        if useMockData {
            loadMockData()
            return
        }

        guard let token = TokenManager.shared.getToken(), !token.isEmpty else {
            errorMessage = "No GitHub token configured"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await fetchAllPRs(token: token)
                self.pullRequests = result.pullRequests
                self.currentUserLogin = result.viewerLogin
                self.lastUpdated = Date()
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Single GraphQL Query

    private func fetchAllPRs(token: String) async throws -> (pullRequests: [PullRequest], viewerLogin: String?) {
        let query = """
        {
          viewer {
            login
          }
          involved: search(query: "is:pr is:open involves:@me sort:updated-desc", type: ISSUE, first: 50) {
            nodes {
              ... on PullRequest {
                id
                number
                title
                url
                isDraft
                updatedAt
                author {
                  login
                }
                mergeable
                repository {
                  nameWithOwner
                  name
                }
                commits(last: 1) {
                  nodes {
                    commit {
                      statusCheckRollup {
                        state
                        contexts(first: 100) {
                          nodes {
                            ... on CheckRun {
                              __typename
                              name
                              status
                              conclusion
                            }
                            ... on StatusContext {
                              __typename
                              context
                              state
                            }
                          }
                        }
                      }
                    }
                  }
                }
                reviews(last: 20) {
                  nodes {
                    id
                    state
                    createdAt
                    author {
                      login
                    }
                  }
                }
                comments(last: 100) {
                  totalCount
                  nodes {
                    id
                    url
                    body
                    createdAt
                    author {
                      login
                    }
                  }
                }
                reviewThreads(last: 50) {
                  nodes {
                    id
                    comments(last: 20) {
                      nodes {
                        id
                        url
                        body
                        createdAt
                        author {
                          login
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          reviewRequests: search(query: "is:pr is:open review-requested:@me sort:updated-desc", type: ISSUE, first: 50) {
            nodes {
              ... on PullRequest {
                id
                number
                title
                url
                isDraft
                updatedAt
                author {
                  login
                }
                mergeable
                repository {
                  nameWithOwner
                  name
                }
                commits(last: 1) {
                  nodes {
                    commit {
                      statusCheckRollup {
                        state
                        contexts(first: 100) {
                          nodes {
                            ... on CheckRun {
                              __typename
                              name
                              status
                              conclusion
                            }
                            ... on StatusContext {
                              __typename
                              context
                              state
                            }
                          }
                        }
                      }
                    }
                  }
                }
                reviews(last: 20) {
                  nodes {
                    id
                    state
                    createdAt
                    author {
                      login
                    }
                  }
                }
                comments(last: 100) {
                  totalCount
                  nodes {
                    id
                    url
                    body
                    createdAt
                    author {
                      login
                    }
                  }
                }
                reviewThreads(last: 50) {
                  nodes {
                    id
                    comments(last: 20) {
                      nodes {
                        id
                        url
                        body
                        createdAt
                        author {
                          login
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """

        let dataObj = try await performGraphQLRequest(token: token, query: query)
        guard let viewer = dataObj.viewer else {
            throw NSError(domain: "GitHub", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unexpected GraphQL response"])
        }
        let viewerLogin = viewer.login
        var byKey: [String: PullRequest] = [:]

        if let involvedNodes = dataObj.involved?.nodes {
            for node in involvedNodes.compactMap({ $0 }) {
                if let pullRequest = parsePullRequestNode(node, isRequestedReviewer: false, viewerLogin: viewerLogin) {
                    byKey["\(pullRequest.repoFullName)#\(pullRequest.number)"] = pullRequest
                }
            }
        }

        if let reviewNodes = dataObj.reviewRequests?.nodes {
            for node in reviewNodes.compactMap({ $0 }) {
                if var pullRequest = parsePullRequestNode(node, isRequestedReviewer: true, viewerLogin: viewerLogin) {
                    let key = "\(pullRequest.repoFullName)#\(pullRequest.number)"
                    if var existing = byKey[key] {
                        existing.isRequestedReviewer = true
                        byKey[key] = existing
                    } else {
                        pullRequest.isRequestedReviewer = true
                        byKey[key] = pullRequest
                    }
                }
            }
        }

        var results = Array(byKey.values)
        results.sort { $0.updatedAt > $1.updatedAt }
        return (pullRequests: results, viewerLogin: viewerLogin)
    }

    private func parsePullRequestNode(_ node: GitHubGraphQLPullRequestResponse, isRequestedReviewer: Bool, viewerLogin: String?) -> PullRequest? {
        guard let number = node.number,
              let title = node.title,
              let urlStr = node.url,
              let url = URL(string: urlStr),
              let repoFullName = node.repository?.nameWithOwner else { return nil }

        let isDraft = node.isDraft ?? false
        let updatedAtStr = node.updatedAt ?? ""
        let updatedAt = parseDate(updatedAtStr) ?? Date()
        let authorLogin = node.author?.login
        let mergeableStr = node.mergeable ?? "UNKNOWN"
        let hasConflicts = mergeableStr == "CONFLICTING"

        // Parse CI status
        var ciStatus: CIStatus = .unknown
        var failedChecks = Set<String>()
        if let commitNodes = node.commits?.nodes?.compactMap({ $0 }),
           let lastCommit = commitNodes.last,
           let rollup = lastCommit.commit?.statusCheckRollup {
            let state = rollup.state ?? "UNKNOWN"
            switch state {
            case "SUCCESS": ciStatus = .success
            case "FAILURE", "ERROR": ciStatus = .failure
            case "PENDING", "EXPECTED": ciStatus = .pending
            default: ciStatus = .unknown
            }

            // Get failed check names
            if let ctxNodes = rollup.contexts?.nodes?.compactMap({ $0 }) {
                for ctx in ctxNodes {
                    switch ctx {
                    case let .checkRun(name, _, conclusion):
                        let conclusion = (conclusion ?? "").uppercased()
                        let failingConclusions: Set<String> = [
                            "FAILURE",
                            "TIMED_OUT",
                            "CANCELLED",
                            "ACTION_REQUIRED",
                            "STARTUP_FAILURE",
                            "STALE"
                        ]
                        if failingConclusions.contains(conclusion) {
                            if let name {
                                failedChecks.insert(name)
                            }
                        }
                    case let .statusContext(context, state):
                        let ctxState = (state ?? "").uppercased()
                        if ctxState == "FAILURE" || ctxState == "ERROR" {
                            if let context {
                                failedChecks.insert(context)
                            }
                        }
                    case .unknown(_):
                        continue
                    }
                }
            }
        }

        // Parse review state + your activity
        var reviewState: ReviewState = .unknown
        var isReviewedByMe = false
        let viewerLoginLower = viewerLogin?.lowercased()
        var hasMyCommentFromReview = false
        if let reviewNodes = node.reviews?.nodes?.compactMap({ $0 }) {
            var latestByUser: [String: String] = [:]
            for review in reviewNodes {
                let state = (review.state ?? "").uppercased()
                if let login = review.author?.login,
                   let viewerLoginLower,
                   login.lowercased() == viewerLoginLower {
                    if state == "COMMENTED" {
                        hasMyCommentFromReview = true
                    } else if state == "APPROVED" || state == "CHANGES_REQUESTED" {
                        isReviewedByMe = true
                    }
                }
                if state == "COMMENTED" { continue }
                if let login = review.author?.login {
                    latestByUser[login] = state
                }
            }
            if latestByUser.values.contains("CHANGES_REQUESTED") {
                reviewState = .changesRequested
            } else if latestByUser.values.contains("APPROVED") {
                reviewState = .approved
            } else if !latestByUser.isEmpty {
                reviewState = .unknown
            }
        }

        // Parse comments (hide selected bots)
        let hiddenBotNames = Set(["tuist", "greplite", "greptile-apps", "github-actions", "[bot]"])
        var recentComments: [PRComment] = []
        var commentCount = 0
        if let comments = node.comments {
            commentCount = comments.totalCount ?? 0
            if let commentNodes = comments.nodes?.compactMap({ $0 }) {
                recentComments = commentNodes.compactMap { c -> PRComment? in
                    guard let login = c.author?.login,
                          let body = c.body,
                          let dateStr = c.createdAt else { return nil }

                    let loginLower = login.lowercased()
                    if hiddenBotNames.contains(where: { loginLower.contains($0) }) {
                        return nil
                    }

                    let id = c.id ?? UUID().uuidString
                    guard let createdAt = parseDate(dateStr) else { return nil }
                    let url = c.url.flatMap { URL(string: $0) }
                    return PRComment(
                        id: id,
                        author: login,
                        body: body,
                        createdAt: createdAt,
                        url: url
                    )
                }
            }
        }

        var reviewThreadModels: [PRCommentThread] = []
        if let threadNodes = node.reviewThreads?.nodes?.compactMap({ $0 }) {
            for thread in threadNodes {
                let threadId = thread.id ?? UUID().uuidString
                guard let commentNodes = thread.comments?.nodes?.compactMap({ $0 }) else { continue }

                let parsed: [PRComment] = commentNodes.compactMap { c -> PRComment? in
                    guard let login = c.author?.login,
                          let body = c.body,
                          let dateStr = c.createdAt else { return nil }

                    let loginLower = login.lowercased()
                    if hiddenBotNames.contains(where: { loginLower.contains($0) }) {
                        return nil
                    }

                    let id = c.id ?? UUID().uuidString
                    guard let createdAt = parseDate(dateStr) else { return nil }
                    let url = c.url.flatMap { URL(string: $0) }
                    return PRComment(
                        id: id,
                        author: login,
                        body: body,
                        createdAt: createdAt,
                        url: url
                    )
                }
                if !parsed.isEmpty {
                    let sorted = parsed.sorted { $0.createdAt > $1.createdAt }
                    let threadModel = PRCommentThread(id: threadId, comments: sorted)
                    reviewThreadModels.append(threadModel)
                }
            }
        }

        recentComments.sort { $0.createdAt > $1.createdAt }
        reviewThreadModels.sort { ($0.latestComment?.createdAt ?? .distantPast) > ($1.latestComment?.createdAt ?? .distantPast) }
        var recentReviews: [PRReview] = []
        if let reviewNodes = node.reviews?.nodes?.compactMap({ $0 }) {
            for review in reviewNodes {
                let state = review.state ?? ""
                if state == "COMMENTED" { continue }
                guard let login = review.author?.login else { continue }

                let loginLower = login.lowercased()
                if hiddenBotNames.contains(where: { loginLower.contains($0) }) {
                    continue
                }

                let id = review.id ?? UUID().uuidString
                let dateStr = review.createdAt ?? ""
                guard let createdAt = parseDate(dateStr) else { continue }
                recentReviews.append(PRReview(id: id, author: login, state: state, createdAt: createdAt))
            }
        }
        recentReviews.sort { $0.createdAt > $1.createdAt }

        var hasMyComment = false
        if let viewerLoginLower, !viewerLoginLower.isEmpty {
            if recentComments.contains(where: { $0.author.lowercased() == viewerLoginLower }) {
                hasMyComment = true
            } else if reviewThreadModels.contains(where: { thread in
                thread.comments.contains(where: { $0.author.lowercased() == viewerLoginLower })
            }) {
                hasMyComment = true
            } else if hasMyCommentFromReview {
                hasMyComment = true
            }
        }

        let stableId = node.id ?? "\(repoFullName)#\(number)"
        return PullRequest(
            id: stableId,
            number: number,
            title: title,
            repoFullName: repoFullName,
            authorLogin: authorLogin,
            htmlURL: url,
            headSHA: "",
            updatedAt: updatedAt,
            commentCount: commentCount,
            isDraft: isDraft,
            ciStatus: ciStatus,
            failedChecks: Array(failedChecks).sorted(),
            reviewState: reviewState,
            hasConflicts: hasConflicts,
            recentReviews: recentReviews,
            recentComments: recentComments,
            reviewThreads: reviewThreadModels,
            isRequestedReviewer: isRequestedReviewer,
            isReviewedByMe: isReviewedByMe,
            hasMyComment: hasMyComment
        )
    }

    private func needsAttention(_ pr: PullRequest) -> Bool {
        guard !pr.isDraft else { return false }
        return pr.ciStatus == .failure || pr.hasConflicts || pr.reviewState == .changesRequested
    }

    private func isMine(_ pr: PullRequest, viewerLoginLower: String) -> Bool {
        pr.authorLogin?.lowercased() == viewerLoginLower
    }

    private func performGraphQLRequest(token: String, query: String) async throws -> GitHubGraphQLPullRequestsResponse {
        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GitHub", code: code, userInfo: [NSLocalizedDescriptionKey: "GraphQL error (HTTP \(code)): \(body.prefix(200))"])
        }

        let response = try decoder.decode(GitHubGraphQLResponse<GitHubGraphQLPullRequestsResponse>.self, from: data)
        if let errors = response.errors, response.data == nil {
            let msg = errors.first?.message ?? "GraphQL error"
            throw NSError(domain: "GitHub", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let dataObj = response.data else {
            throw NSError(domain: "GitHub", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unexpected GraphQL response"])
        }
        return dataObj
    }

    private func parseDate(_ dateString: String) -> Date? {
        if let date = Self.isoFormatterWithFractional.date(from: dateString) {
            return date
        }
        return Self.isoFormatter.date(from: dateString)
    }

    // MARK: - Mock Data

    private static let mockPullRequests: [PullRequest] = [
            PullRequest(
            id: "acme/frontend#142", number: 142, title: "feat: Add dark mode support across all components",
                repoFullName: "acme/frontend", authorLogin: "sarah", htmlURL: URL(string: "https://github.com")!,
                headSHA: "abc123", updatedAt: Date().addingTimeInterval(-3600), commentCount: 3, isDraft: false,
                ciStatus: .success, failedChecks: [], reviewState: .approved,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: "mock-1", author: "sarah", body: "LGTM! Nice work on the color tokens.", createdAt: Date().addingTimeInterval(-3600), url: URL(string: "https://github.com")),
                    PRComment(id: "mock-2", author: "mike", body: "Approved — tested on Safari and Chrome.", createdAt: Date().addingTimeInterval(-1800), url: URL(string: "https://github.com"))
                ],
                isRequestedReviewer: true
            ),
            PullRequest(
                id: "acme/backend-api#87", number: 87, title: "fix: Resolve memory leak in WebSocket connection handler",
                repoFullName: "acme/backend-api", authorLogin: "alex", htmlURL: URL(string: "https://github.com")!,
                headSHA: "def456", updatedAt: Date().addingTimeInterval(-7200), commentCount: 5, isDraft: false,
                ciStatus: .failure, failedChecks: ["Build / test-linux", "CI / integration-tests"], reviewState: .changesRequested,
                hasConflicts: true,
                recentComments: [
                    PRComment(id: "mock-3", author: "alex", body: "The connection pool still leaks under high concurrency. See my inline comments.", createdAt: Date().addingTimeInterval(-7200), url: URL(string: "https://github.com"))
                ],
                reviewThreads: [
                    PRCommentThread(
                        id: "thread-1",
                        comments: [
                            PRComment(id: "mock-3a", author: "jordan", body: "This block looks suspicious. Can we add a test for this path?", createdAt: Date().addingTimeInterval(-14400), url: URL(string: "https://github.com")),
                            PRComment(id: "mock-3b", author: "karim", body: "Good catch. I’ll add coverage and re-run the suite.", createdAt: Date().addingTimeInterval(-10800), url: URL(string: "https://github.com"))
                        ]
                    ),
                    PRCommentThread(
                        id: "thread-2",
                        comments: [
                            PRComment(id: "mock-3c", author: "alex", body: "We should also ensure the timeout doesn’t leak sockets.", createdAt: Date().addingTimeInterval(-9000), url: URL(string: "https://github.com")),
                            PRComment(id: "mock-3d", author: "sarah", body: "Agreed — I’ll add a regression test before merge.", createdAt: Date().addingTimeInterval(-7200), url: URL(string: "https://github.com"))
                        ]
                    )
                ]
            ),
            PullRequest(
                id: "acme/infrastructure#201", number: 201, title: "chore: Bump dependencies and fix security advisories",
                repoFullName: "acme/infrastructure", authorLogin: "dana", htmlURL: URL(string: "https://github.com")!,
                headSHA: "ghi789", updatedAt: Date().addingTimeInterval(-10800), commentCount: 0, isDraft: false,
                ciStatus: .pending, failedChecks: [], reviewState: .pending,
                hasConflicts: false, recentComments: []
            ),
            PullRequest(
                id: "acme/frontend#55", number: 55, title: "WIP: Experiment with new caching strategy for GraphQL queries",
                repoFullName: "acme/frontend", authorLogin: "karim", htmlURL: URL(string: "https://github.com")!,
                headSHA: "jkl012", updatedAt: Date().addingTimeInterval(-86400), commentCount: 1, isDraft: true,
                ciStatus: .unknown, failedChecks: [], reviewState: .unknown,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: "mock-4", author: "karim", body: "Still exploring — don't review yet", createdAt: Date().addingTimeInterval(-86400), url: URL(string: "https://github.com"))
                ]
            ),
            PullRequest(
                id: "acme/auth-service#33", number: 33, title: "feat: Add OAuth2 PKCE flow for mobile clients",
                repoFullName: "acme/auth-service", authorLogin: "karim", htmlURL: URL(string: "https://github.com")!,
                headSHA: "mno345", updatedAt: Date().addingTimeInterval(-600), commentCount: 8, isDraft: false,
                ciStatus: .success, failedChecks: [], reviewState: .approved,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: "mock-5", author: "dana", body: "Ship it! 🚀", createdAt: Date().addingTimeInterval(-600), url: URL(string: "https://github.com"))
                ]
            ),
            PullRequest(
                id: "acme/backend-api#12", number: 12, title: "fix: Rate limiter bypassed when API key rotates mid-request",
                repoFullName: "acme/backend-api", authorLogin: "jordan", htmlURL: URL(string: "https://github.com")!,
                headSHA: "pqr678", updatedAt: Date().addingTimeInterval(-5400), commentCount: 2, isDraft: false,
                ciStatus: .failure, failedChecks: ["CI / lint"], reviewState: .pending,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: "mock-6", author: "jordan", body: "Can you add a test for the rotation edge case?", createdAt: Date().addingTimeInterval(-5400), url: URL(string: "https://github.com"))
                ]
            ),
        ]

    private func loadMockData() {
        isLoading = true
        pullRequests = Self.mockPullRequests
        lastUpdated = Date()
        isLoading = false
    }
}

extension GitHubService {
    static func preview() -> GitHubService {
        let service = GitHubService()
        service.pullRequests = Self.mockPullRequests
        service.lastUpdated = Date()
        service.currentUserLogin = "karim"
        service.permissionsState = PermissionsState(
            canReadPullRequests: true,
            canReadCommitStatuses: true,
            canReadReviews: true,
            canReadComments: true
        )
        return service
    }
}
