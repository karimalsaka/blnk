import SwiftUI

struct OnboardingInstructionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let tagText: String?
    let tagTint: Color
    let actionTitle: String
    let action: () -> Void
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tagText: String? = nil,
        tagTint: Color = AppTheme.accent,
        actionTitle: String = "Open GitHub",
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tagText = tagText
        self.tagTint = tagTint
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let tagText {
                    AppTag(text: tagText, icon: "sparkles", tint: tagTint)
                }
            }

            content

            HStack {
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(AppSoftButtonStyle(tint: AppTheme.accent))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.stroke.opacity(0.8), lineWidth: 1)
                )
        )
    }
}
