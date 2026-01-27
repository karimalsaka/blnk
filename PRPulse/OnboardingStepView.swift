import SwiftUI

struct OnboardingStepView<Content: View>: View {
    let title: String
    let subtitle: String?
    let iconName: String
    let iconColor: Color
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        iconName: String,
        iconColor: Color = .blue,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        AppCard {
            VStack(spacing: 24) {
                // Icon Header
                iconHeader

                // Title and Subtitle
                headerText

                // Content
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(32)
        }
    }

    // MARK: - Icon Header

    private var iconHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.badgeGradient.opacity(0.2))
                .frame(width: 92, height: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.stroke.opacity(0.6), lineWidth: 1)
                )

            Image(systemName: iconName)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundColor(iconColor)
        }
    }

    // MARK: - Header Text

    private var headerText: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingStepView(
        title: "Welcome to PRPulse",
        subtitle: "Monitor your GitHub pull requests from your menu bar",
        iconName: "bolt.circle.fill",
        iconColor: .blue
    ) {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRPulse helps you stay on top of your pull requests with:")
                .font(.subheadline)

            BulletPointView(text: "Real-time status updates")
            BulletPointView(text: "CI/CD check monitoring")
            BulletPointView(text: "Review state tracking")
            BulletPointView(text: "Recent comment notifications")
        }
    }
    .frame(width: 600)
}

// MARK: - Bullet Point Helper

struct BulletPointView: View {
    let text: String
    let iconName: String

    init(text: String, iconName: String = "checkmark.circle.fill") {
        self.text = text
        self.iconName = iconName
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(AppTheme.success)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16)

            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}
