import Foundation

// MARK: - Filters

enum PRFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case needsAttention = "Needs Attention"
    case approved = "Approved"
    case drafts = "Drafts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .needsAttention: return "exclamationmark.circle.fill"
        case .approved: return "checkmark.seal.fill"
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
    let id: Int
    let number: Int
    let title: String
    let repoFullName: String
    let htmlURL: URL
    let headSHA: String
    let commentCount: Int
    let isDraft: Bool
    var ciStatus: CIStatus = .unknown
    var failedChecks: [String] = []
    var reviewState: ReviewState = .unknown
    var isMergeable: Bool? = nil
    var hasConflicts: Bool = false
    var recentComments: [PRComment] = []
    var isRequestedReviewer: Bool = false
    var isReviewedByMe: Bool = false

    var repoName: String {
        repoFullName.components(separatedBy: "/").last ?? repoFullName
    }

    var ownerName: String {
        repoFullName.components(separatedBy: "/").first ?? ""
    }

    static func == (lhs: PullRequest, rhs: PullRequest) -> Bool {
        lhs.id == rhs.id
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

    var preview: String {
        let trimmed = body.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "…"
        }
        return trimmed
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
