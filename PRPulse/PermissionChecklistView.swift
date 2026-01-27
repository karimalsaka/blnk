import SwiftUI

struct PermissionChecklistView: View {
    let validationResult: TokenValidationService.TokenValidationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            permissionsList
            summarySection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.stroke.opacity(0.6), lineWidth: 1)
                )
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: validationResult.allPermissionsGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(validationResult.allPermissionsGranted ? AppTheme.success : AppTheme.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Token Validation Results")
                    .font(.headline)
                Text(validationResult.allPermissionsGranted ? "All permissions granted" : "Some permissions missing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Permissions List

    private var permissionsList: some View {
        VStack(spacing: 12) {
            ForEach(validationResult.permissions, id: \.name) { permission in
                PermissionRowView(permission: permission)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !validationResult.allPermissionsGranted && validationResult.hasMinimumPermissions {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AppTheme.accent)
                    Text("PRPulse will work — the missing permission only hides related info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(AppTheme.accentSoft)
                .cornerRadius(10)
            } else if !validationResult.hasMinimumPermissions {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.danger)
                    Text("Minimum permissions required to use the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(AppTheme.dangerSoft)
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Permission Row

struct PermissionRowView: View {
    let permission: TokenValidationService.PermissionCheck

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status Icon
            statusIcon
                .frame(width: 24)

            // Permission Details
            VStack(alignment: .leading, spacing: 4) {
                Text(permission.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(permission.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let errorMessage = permission.errorMessage,
                   permission.status != .granted {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption2)
                        Text(errorMessage)
                            .font(.caption2)
                    }
                    .foregroundColor(AppTheme.danger)
                    .padding(.top, 2)
                }

                if let scope = permission.requiredScope,
                   permission.status == .denied {
                    Text("Required: \(scope)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.warning)
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(8)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 24, height: 24)

            Image(systemName: statusIconName)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }

    private var backgroundColor: Color {
        switch permission.status {
        case .granted:
            return AppTheme.successSoft
        case .denied:
            return AppTheme.dangerSoft
        case .unknown:
            return AppTheme.warningSoft
        }
    }

    private var statusColor: Color {
        switch permission.status {
        case .granted:
            return AppTheme.success
        case .denied:
            return AppTheme.danger
        case .unknown:
            return AppTheme.warning
        }
    }

    private var statusIconName: String {
        switch permission.status {
        case .granted:
            return "checkmark"
        case .denied:
            return "xmark"
        case .unknown:
            return "questionmark"
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionChecklistView(
        validationResult: TokenValidationService.TokenValidationResult(
            isValid: true,
            canReadPullRequests: TokenValidationService.PermissionCheck(
                name: "Pull Requests",
                description: "View your open pull requests",
                status: .granted,
                errorMessage: nil,
                requiredScope: nil
            ),
            canReadCommitStatuses: TokenValidationService.PermissionCheck(
                name: "CI/CD Status",
                description: "View commit status checks and CI results",
                status: .denied,
                errorMessage: "Missing commit status permission",
                requiredScope: "repo:status"
            ),
            canReadReviews: TokenValidationService.PermissionCheck(
                name: "Reviews",
                description: "View PR review states and approvals",
                status: .granted,
                errorMessage: nil,
                requiredScope: nil
            ),
            canReadComments: TokenValidationService.PermissionCheck(
                name: "Comments",
                description: "View PR comments and discussions",
                status: .granted,
                errorMessage: nil,
                requiredScope: nil
            ),
            viewer: "testuser"
        )
    )
    .frame(width: 500)
    .padding()
}
