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
        VStack(spacing: 0) {
            if let heroImageName {
                OnboardingHeroImage(
                    name: heroImageName,
                    accessibilityLabel: heroAccessibilityLabel
                )
                .padding(.bottom, 20)
            }

            headerText
                .padding(.bottom, 24)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Header Text

    private var headerText: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingHeroImage: View {
    let name: String
    let accessibilityLabel: String?

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
            .scaledToFit()
            .frame(height: 80)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel ?? "")
            .accessibilityHidden(accessibilityLabel == nil)
    }
}

// MARK: - Preview

struct OnboardingStepView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingStepView(
            title: "blnk",
            subtitle: "Your pull requests, always visible",
            heroImageName: "ghost-image-large",
            heroAccessibilityLabel: "blnk"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Features:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 600)
        .padding()
        .preferredColorScheme(.dark)
    }
}
