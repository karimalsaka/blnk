import SwiftUI

struct OnboardingStepView<Content: View>: View {
    let title: String
    let subtitle: String?
    let heroImageName: String?
    let heroAccessibilityLabel: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        heroImageName: String? = nil,
        heroAccessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.heroImageName = heroImageName
        self.heroAccessibilityLabel = heroAccessibilityLabel
        self.content = content()
    }

    var body: some View {
        OnboardingCard {
            VStack(spacing: 24) {
                if let heroImageName {
                    OnboardingHeroImage(
                        name: heroImageName,
                        accessibilityLabel: heroAccessibilityLabel
                    )
                }

                // Title and Subtitle
                headerText

                // Content
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

private struct OnboardingCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.strokeStrong.opacity(0.9), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.10),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .blendMode(.overlay)
                    )
            )
            .shadow(color: AppTheme.cardShadow.opacity(0.30), radius: 14, x: 0, y: 10)
    }
}

private struct OnboardingHeroImage: View {
    let name: String
    let accessibilityLabel: String?

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(Color.white.opacity(0.92))
            .scaledToFit()
            .frame(height: 150)
            .shadow(color: AppTheme.cardShadow.opacity(0.55), radius: 18, x: 0, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityHidden(accessibilityLabel == nil)
    }
}

// MARK: - Preview

struct OnboardingStepView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingStepView(
            title: "Welcome to blnk",
            subtitle: "Monitor your GitHub pull requests from your menu bar",
            heroImageName: "ghost-image-large",
            heroAccessibilityLabel: "blnk"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("blnk helps you stay on top of your pull requests with:")
                    .font(.subheadline)

                BulletPointView(text: "Real-time status updates")
                BulletPointView(text: "CI/CD check monitoring")
                BulletPointView(text: "Review state tracking")
                BulletPointView(text: "Recent comment notifications")
            }
        }
        .frame(width: 600)
        .padding()
        .preferredColorScheme(.dark)
    }
}

// MARK: - Bullet Point Helper

struct BulletPointView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}
