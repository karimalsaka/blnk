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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))

                        if tagText != nil {
                            Text("Recommended")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(AppTheme.successSoft)
                                )
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }

            content
                .padding(.leading, 1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
        )
    }
}
