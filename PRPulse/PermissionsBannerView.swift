import SwiftUI

struct PermissionsBannerView: View {
    let permissionsState: PermissionsState
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Banner Header
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.warning)
                        .font(.caption)

                    Text("Limited Permissions")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Some features are unavailable due to missing token permissions:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        if !permissionsState.canReadCommitStatuses {
                            PermissionLimitationRow(
                                icon: "xmark.circle.fill",
                                text: "CI/CD status checks are hidden"
                            )
                        }

                        if !permissionsState.canReadReviews {
                            PermissionLimitationRow(
                                icon: "xmark.circle.fill",
                                text: "Review states are hidden"
                            )
                        }

                        if !permissionsState.canReadComments {
                            PermissionLimitationRow(
                                icon: "xmark.circle.fill",
                                text: "Comments are hidden"
                            )
                        }
                    }

                    Text("Update your token permissions in Settings to enable all features.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.warningSoft)
        )
    }
}

struct PermissionLimitationRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(AppTheme.warning)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("All Permissions") {
    PermissionsBannerView(permissionsState: PermissionsState(
        canReadPullRequests: true,
        canReadCommitStatuses: true,
        canReadReviews: true,
        canReadComments: true
    ))
    .frame(width: 400)
}

#Preview("Limited Permissions") {
    PermissionsBannerView(permissionsState: PermissionsState(
        canReadPullRequests: true,
        canReadCommitStatuses: false,
        canReadReviews: false,
        canReadComments: true
    ))
    .frame(width: 400)
}
