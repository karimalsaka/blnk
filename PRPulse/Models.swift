import Foundation

// MARK: - Filters

enum PRFilter: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case review = "To Review"
    case discussed = "Discussed"
    case mine = "Mine"
    case drafts = "Drafts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inbox: return "tray.full.fill"
        case .review: return "eye.circle.fill"
        case .discussed: return "bubble.left.and.bubble.right.fill"
        case .mine: return "person.crop.circle.fill"
        case .drafts: return "doc.fill"
        }
    }
}

// MARK: - Domain Models

enum CIStatus: String, Codable {
    case success, failure, pending, unknown

    var label: String {
        switch self {
        case .success: return "Passing"
        case .failure: return "Failing"
        case .pending: return "Running"
        case .unknown: return "No Checks"
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .pending: return "clock.circle.fill"
        case .unknown: return "minus.circle"
        }
    }

    var color: String {
        switch self {
        case .success: return "green"
        case .failure: return "red"
        case .pending: return "orange"
        case .unknown: return "gray"
        }
    }
}

enum ReviewState: String, Codable {
    case approved, changesRequested, pending, unknown

    var label: String {
        switch self {
        case .approved: return "Approved"
        case .changesRequested: return "Changes Requested"
        case .pending: return "Review Pending"
        case .unknown: return "No Reviews"
        }
    }

    var icon: String {
        switch self {
        case .approved: return "checkmark.seal.fill"
        case .changesRequested: return "exclamationmark.triangle.fill"
        case .pending: return "clock.fill"
        case .unknown: return "person.crop.circle"
        }
    }
}

struct PullRequest: Identifiable, Equatable {
    let id: String
    let number: Int
    let title: String
    let repoFullName: String
    let authorLogin: String?
    let htmlURL: URL
    let headSHA: String
    let updatedAt: Date
    let commentCount: Int
    let isDraft: Bool
    var ciStatus: CIStatus = .unknown
    var failedChecks: [String] = []
    var reviewState: ReviewState = .unknown
    var isMergeable: Bool? = nil
    var hasConflicts: Bool = false
    var recentReviews: [PRReview] = []
    var recentComments: [PRComment] = []
    var reviewThreads: [PRCommentThread] = []
    var isRequestedReviewer: Bool = false
    var isReviewedByMe: Bool = false
    var hasMyComment: Bool = false

    var repoName: String {
        repoFullName.components(separatedBy: "/").last ?? repoFullName
    }

    var ownerName: String {
        repoFullName.components(separatedBy: "/").first ?? ""
    }

    static func == (lhs: PullRequest, rhs: PullRequest) -> Bool {
        lhs.id == rhs.id
    }

    var allComments: [PRComment] {
        let threaded = reviewThreads.flatMap { $0.comments }
        return (recentComments + threaded).sorted { $0.createdAt > $1.createdAt }
    }

    var rowIdentity: String {
        "\(id)-\(updatedAt.timeIntervalSince1970)"
    }
}

// MARK: - GitHub API Response Models

struct SearchResponse: Codable {
    let items: [SearchItem]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

struct SearchItem: Codable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String
    let comments: Int
    let draft: Bool?
    let pullRequest: PullRequestLinks?
    let repositoryUrl: String

    enum CodingKeys: String, CodingKey {
        case id, number, title
        case htmlUrl = "html_url"
        case comments, draft
        case pullRequest = "pull_request"
        case repositoryUrl = "repository_url"
    }

    var repoFullName: String {
        // repositoryUrl is like https://api.github.com/repos/owner/name
        let parts = repositoryUrl.components(separatedBy: "/repos/")
        return parts.last ?? ""
    }
}

struct PullRequestLinks: Codable {
    let url: String
}

struct PRDetailResponse: Codable {
    let head: PRHead
    let mergeable: Bool?
    let mergeableState: String?
    let mergeable_state: String?

    var effectiveMergeableState: String? {
        mergeableState ?? mergeable_state
    }
}

struct PRHead: Codable {
    let sha: String
}

struct CheckRunsResponse: Codable {
    let totalCount: Int
    let checkRuns: [CheckRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case checkRuns = "check_runs"
    }
}

struct CheckRun: Codable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
}

struct ReviewResponse: Codable {
    let id: Int
    let state: String
    let user: ReviewUser
}

struct ReviewUser: Codable {
    let login: String
}

struct PRComment: Identifiable, Equatable {
    let id: String
    let author: String
    let body: String
    let createdAt: Date
    let url: URL?

    var preview: String {
        let trimmed = body.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "…"
        }
        return trimmed
    }
}

struct PRCommentThread: Identifiable, Equatable {
    let id: String
    var comments: [PRComment]

    var latestComment: PRComment? {
        comments.max(by: { $0.createdAt < $1.createdAt })
    }
}

struct PRReview: Identifiable, Equatable {
    let id: String
    let author: String
    let state: String
    let createdAt: Date

    var label: String {
        switch state {
        case "APPROVED": return "Approved"
        case "CHANGES_REQUESTED": return "Changes Requested"
        case "DISMISSED": return "Dismissed"
        case "PENDING": return "Pending"
        default: return "Review"
        }
    }
}

struct IssueCommentResponse: Codable {
    let id: Int
    let body: String
    let createdAt: String
    let user: ReviewUser

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case createdAt = "created_at"
    }
}

// MARK: - GraphQL Response Models

struct GitHubGraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GitHubGraphQLError]?
}

struct GitHubGraphQLError: Decodable {
    let message: String
}

struct GitHubGraphQLPullRequestsResponse: Decodable {
    let viewer: GitHubGraphQLViewerResponse?
    let involved: GitHubGraphQLSearchResponse?
    let reviewRequests: GitHubGraphQLSearchResponse?
}

struct GitHubGraphQLViewerResponse: Decodable {
    let login: String?
    let pullRequests: GitHubGraphQLPullRequestConnectionResponse?
}

struct GitHubGraphQLPullRequestConnectionResponse: Decodable {
    let nodes: [GitHubGraphQLPullRequestResponse?]?
}

struct GitHubGraphQLSearchResponse: Decodable {
    let nodes: [GitHubGraphQLPullRequestResponse?]?
}

struct GitHubGraphQLPullRequestResponse: Decodable {
    let id: String?
    let number: Int?
    let title: String?
    let url: String?
    let isDraft: Bool?
    let updatedAt: String?
    let author: GitHubGraphQLUserResponse?
    let mergeable: String?
    let repository: GitHubGraphQLRepositoryResponse?
    let commits: GitHubGraphQLCommitConnectionResponse?
    let reviews: GitHubGraphQLReviewConnectionResponse?
    let comments: GitHubGraphQLCommentConnectionResponse?
    let reviewThreads: GitHubGraphQLReviewThreadConnectionResponse?
}

struct GitHubGraphQLUserResponse: Decodable {
    let login: String?
}

struct GitHubGraphQLRepositoryResponse: Decodable {
    let nameWithOwner: String?
    let name: String?
}

struct GitHubGraphQLCommitConnectionResponse: Decodable {
    let nodes: [GitHubGraphQLCommitNodeResponse?]?
}

struct GitHubGraphQLCommitNodeResponse: Decodable {
    let commit: GitHubGraphQLCommitResponse?
}

struct GitHubGraphQLCommitResponse: Decodable {
    let statusCheckRollup: GitHubGraphQLStatusCheckRollupResponse?
}

struct GitHubGraphQLStatusCheckRollupResponse: Codable {
    let state: String?
    let contexts: GitHubGraphQLStatusContextConnectionResponse?
}

struct GitHubGraphQLStatusContextConnectionResponse: Codable {
    let nodes: [GitHubGraphQLStatusContextNodeResponse?]?
}

enum GitHubGraphQLStatusContextNodeResponse: Codable {
    case checkRun(name: String?, status: String?, conclusion: String?)
    case statusContext(context: String?, state: String?)
    case unknown(typeName: String)

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case name
        case status
        case conclusion
        case context
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "CheckRun":
            let name = try container.decodeIfPresent(String.self, forKey: .name)
            let status = try container.decodeIfPresent(String.self, forKey: .status)
            let conclusion = try container.decodeIfPresent(String.self, forKey: .conclusion)
            self = .checkRun(name: name, status: status, conclusion: conclusion)
        case "StatusContext":
            let context = try container.decodeIfPresent(String.self, forKey: .context)
            let state = try container.decodeIfPresent(String.self, forKey: .state)
            self = .statusContext(context: context, state: state)
        default:
            self = .unknown(typeName: typeName)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .checkRun(name, status, conclusion):
            try container.encode("CheckRun", forKey: .typeName)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(status, forKey: .status)
            try container.encodeIfPresent(conclusion, forKey: .conclusion)
        case let .statusContext(context, state):
            try container.encode("StatusContext", forKey: .typeName)
            try container.encodeIfPresent(context, forKey: .context)
            try container.encodeIfPresent(state, forKey: .state)
        case let .unknown(typeName):
            try container.encode(typeName, forKey: .typeName)
        }
    }
}

struct GitHubGraphQLReviewConnectionResponse: Decodable {
    let nodes: [GitHubGraphQLReviewResponse?]?
}

struct GitHubGraphQLReviewResponse: Decodable {
    let id: String?
    let state: String?
    let createdAt: String?
    let author: GitHubGraphQLUserResponse?
}

struct GitHubGraphQLCommentConnectionResponse: Decodable {
    let totalCount: Int?
    let nodes: [GitHubGraphQLCommentResponse?]?
}

struct GitHubGraphQLCommentResponse: Decodable {
    let id: String?
    let url: String?
    let body: String?
    let createdAt: String?
    let author: GitHubGraphQLUserResponse?
}

struct GitHubGraphQLReviewThreadConnectionResponse: Decodable {
    let nodes: [GitHubGraphQLReviewThreadResponse?]?
}

struct GitHubGraphQLReviewThreadResponse: Decodable {
    let id: String?
    let comments: GitHubGraphQLCommentConnectionResponse?
}
