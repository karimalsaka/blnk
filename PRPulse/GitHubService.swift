import Foundation

@MainActor
final class GitHubService: ObservableObject {
    @Published var pullRequests: [PullRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var activeFilter: PRFilter = .all
    @Published var useMockData = false

    var filteredPullRequests: [PullRequest] {
        switch activeFilter {
        case .all: return pullRequests
        case .needsAttention: return pullRequests.filter { $0.ciStatus == .failure || $0.hasConflicts || $0.reviewState == .changesRequested }
        case .approved: return pullRequests.filter { $0.reviewState == .approved }
        case .drafts: return pullRequests.filter { $0.isDraft }
        }
    }

    private var timer: Timer?
    private let pollInterval: TimeInterval = 300
    private let graphQLURL = URL(string: "https://api.github.com/graphql")!
    private let decoder = JSONDecoder()

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
        if pullRequests.contains(where: { $0.ciStatus == .pending || $0.reviewState == .pending }) {
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
                let prs = try await fetchAllPRs(token: token)
                self.pullRequests = prs
                self.lastUpdated = Date()
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Single GraphQL Query

    private func fetchAllPRs(token: String) async throws -> [PullRequest] {
        let query = """
        {
          viewer {
            pullRequests(first: 50, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
              nodes {
                id
                number
                title
                url
                isDraft
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
                        contexts(first: 30) {
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
                    state
                    author {
                      login
                    }
                  }
                }
                comments(last: 5) {
                  totalCount
                  nodes {
                    id
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
        """

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

        // Parse the GraphQL response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let viewer = dataObj["viewer"] as? [String: Any],
              let pullRequests = viewer["pullRequests"] as? [String: Any],
              let nodes = pullRequests["nodes"] as? [[String: Any]] else {

            // Check for GraphQL errors
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errors = json["errors"] as? [[String: Any]],
               let msg = errors.first?["message"] as? String {
                throw NSError(domain: "GitHub", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "GitHub", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unexpected GraphQL response"])
        }

        let botNames = Set(["codecov", "dependabot", "renovate", "github-actions", "sonarcloud", "vercel", "netlify", "tuist", "reptile"])

        return nodes.compactMap { node -> PullRequest? in
            guard let number = node["number"] as? Int,
                  let title = node["title"] as? String,
                  let urlStr = node["url"] as? String,
                  let url = URL(string: urlStr),
                  let repo = node["repository"] as? [String: Any],
                  let repoFullName = repo["nameWithOwner"] as? String else { return nil }

            let isDraft = node["isDraft"] as? Bool ?? false
            let mergeableStr = node["mergeable"] as? String ?? "UNKNOWN"
            let hasConflicts = mergeableStr == "CONFLICTING"

            // Parse CI status
            var ciStatus: CIStatus = .unknown
            var failedChecks: [String] = []
            if let commits = node["commits"] as? [String: Any],
               let commitNodes = commits["nodes"] as? [[String: Any]],
               let lastCommit = commitNodes.last,
               let commit = lastCommit["commit"] as? [String: Any],
               let rollup = commit["statusCheckRollup"] as? [String: Any] {

                let state = rollup["state"] as? String ?? "UNKNOWN"
                switch state {
                case "SUCCESS": ciStatus = .success
                case "FAILURE", "ERROR": ciStatus = .failure
                case "PENDING", "EXPECTED": ciStatus = .pending
                default: ciStatus = .unknown
                }

                // Get failed check names
                if ciStatus == .failure,
                   let contexts = rollup["contexts"] as? [String: Any],
                   let ctxNodes = contexts["nodes"] as? [[String: Any]] {
                    for ctx in ctxNodes {
                        let typeName = ctx["__typename"] as? String ?? ""
                        if typeName == "CheckRun" {
                            let conclusion = ctx["conclusion"] as? String ?? ""
                            if conclusion == "FAILURE" || conclusion == "TIMED_OUT" || conclusion == "CANCELLED" {
                                if let name = ctx["name"] as? String {
                                    failedChecks.append(name)
                                }
                            }
                        } else if typeName == "StatusContext" {
                            let ctxState = ctx["state"] as? String ?? ""
                            if ctxState == "FAILURE" || ctxState == "ERROR" {
                                if let context = ctx["context"] as? String {
                                    failedChecks.append(context)
                                }
                            }
                        }
                    }
                }
            }

            // Parse review state
            var reviewState: ReviewState = .unknown
            if let reviews = node["reviews"] as? [String: Any],
               let reviewNodes = reviews["nodes"] as? [[String: Any]] {
                var latestByUser: [String: String] = [:]
                for review in reviewNodes {
                    let state = review["state"] as? String ?? ""
                    if state == "COMMENTED" { continue }
                    if let author = review["author"] as? [String: Any],
                       let login = author["login"] as? String {
                        latestByUser[login] = state
                    }
                }
                if latestByUser.values.contains("CHANGES_REQUESTED") {
                    reviewState = .changesRequested
                } else if latestByUser.values.contains("APPROVED") {
                    reviewState = .approved
                } else if !latestByUser.isEmpty {
                    reviewState = .pending
                }
            }

            // Parse comments (filter bots)
            var recentComments: [PRComment] = []
            var commentCount = 0
            if let comments = node["comments"] as? [String: Any] {
                commentCount = comments["totalCount"] as? Int ?? 0
                if let commentNodes = comments["nodes"] as? [[String: Any]] {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    recentComments = commentNodes.compactMap { c -> PRComment? in
                        guard let author = c["author"] as? [String: Any],
                              let login = author["login"] as? String,
                              let body = c["body"] as? String,
                              let dateStr = c["createdAt"] as? String else { return nil }

                        let loginLower = login.lowercased()
                        let isBot = loginLower.contains("bot")
                            || loginLower.contains("[bot]")
                            || botNames.contains(where: { loginLower.contains($0) })
                        if isBot { return nil }

                        // Use databaseId or hash for stable ID
                        let id = c["id"] as? String ?? ""
                        return PRComment(
                            id: id.hashValue,
                            author: login,
                            body: body,
                            createdAt: formatter.date(from: dateStr) ?? Date()
                        )
                    }
                }
            }

            return PullRequest(
                id: number,
                number: number,
                title: title,
                repoFullName: repoFullName,
                htmlURL: url,
                headSHA: "",
                commentCount: commentCount,
                isDraft: isDraft,
                ciStatus: ciStatus,
                failedChecks: failedChecks,
                reviewState: reviewState,
                hasConflicts: hasConflicts,
                recentComments: recentComments
            )
        }
    }

    // MARK: - Mock Data

    private func loadMockData() {
        isLoading = true
        let mockPRs: [PullRequest] = [
            PullRequest(
                id: 1, number: 142, title: "feat: Add dark mode support across all components",
                repoFullName: "acme/frontend", htmlURL: URL(string: "https://github.com")!,
                headSHA: "abc123", commentCount: 3, isDraft: false,
                ciStatus: .success, failedChecks: [], reviewState: .approved,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: 1, author: "sarah", body: "LGTM! Nice work on the color tokens.", createdAt: Date().addingTimeInterval(-3600)),
                    PRComment(id: 2, author: "mike", body: "Approved — tested on Safari and Chrome.", createdAt: Date().addingTimeInterval(-1800))
                ]
            ),
            PullRequest(
                id: 2, number: 87, title: "fix: Resolve memory leak in WebSocket connection handler",
                repoFullName: "acme/backend-api", htmlURL: URL(string: "https://github.com")!,
                headSHA: "def456", commentCount: 5, isDraft: false,
                ciStatus: .failure, failedChecks: ["Build / test-linux", "CI / integration-tests"], reviewState: .changesRequested,
                hasConflicts: true,
                recentComments: [
                    PRComment(id: 3, author: "alex", body: "The connection pool still leaks under high concurrency. See my inline comments.", createdAt: Date().addingTimeInterval(-7200))
                ]
            ),
            PullRequest(
                id: 3, number: 201, title: "chore: Bump dependencies and fix security advisories",
                repoFullName: "acme/infrastructure", htmlURL: URL(string: "https://github.com")!,
                headSHA: "ghi789", commentCount: 0, isDraft: false,
                ciStatus: .pending, failedChecks: [], reviewState: .pending,
                hasConflicts: false, recentComments: []
            ),
            PullRequest(
                id: 4, number: 55, title: "WIP: Experiment with new caching strategy for GraphQL queries",
                repoFullName: "acme/frontend", htmlURL: URL(string: "https://github.com")!,
                headSHA: "jkl012", commentCount: 1, isDraft: true,
                ciStatus: .unknown, failedChecks: [], reviewState: .unknown,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: 4, author: "karim", body: "Still exploring — don't review yet", createdAt: Date().addingTimeInterval(-86400))
                ]
            ),
            PullRequest(
                id: 5, number: 33, title: "feat: Add OAuth2 PKCE flow for mobile clients",
                repoFullName: "acme/auth-service", htmlURL: URL(string: "https://github.com")!,
                headSHA: "mno345", commentCount: 8, isDraft: false,
                ciStatus: .success, failedChecks: [], reviewState: .approved,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: 5, author: "dana", body: "Ship it! 🚀", createdAt: Date().addingTimeInterval(-600))
                ]
            ),
            PullRequest(
                id: 6, number: 12, title: "fix: Rate limiter bypassed when API key rotates mid-request",
                repoFullName: "acme/backend-api", htmlURL: URL(string: "https://github.com")!,
                headSHA: "pqr678", commentCount: 2, isDraft: false,
                ciStatus: .failure, failedChecks: ["CI / lint"], reviewState: .pending,
                hasConflicts: false,
                recentComments: [
                    PRComment(id: 6, author: "jordan", body: "Can you add a test for the rotation edge case?", createdAt: Date().addingTimeInterval(-5400))
                ]
            ),
        ]
        pullRequests = mockPRs
        lastUpdated = Date()
        isLoading = false
    }
}
