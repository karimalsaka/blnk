import SwiftUI

struct OnboardingPreviewSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AppTheme.badgeGradient)
                    .frame(width: 40, height: 6)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()
                AppTag(text: "Preview", icon: "sparkles", tint: AppTheme.accent)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .overlay(AppTheme.strokeStrong)

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.strokeStrong, lineWidth: 1)
                )
                .shadow(color: AppTheme.cardShadow.opacity(0.18), radius: 6, x: 0, y: 4)
        )
    }
}
