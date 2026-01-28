import SwiftUI

enum AppTheme {
    // Strong Blue theme
    static let accent = Color(red: 0.16, green: 0.46, blue: 0.94)
    static let accentStrong = Color(red: 0.12, green: 0.40, blue: 0.88)
    static let success = Color(red: 0.34, green: 0.76, blue: 0.54)
    static let danger = Color(red: 0.86, green: 0.36, blue: 0.38)
    static let warning = Color(red: 0.92, green: 0.56, blue: 0.26)
    static let info = Color(red: 0.56, green: 0.72, blue: 0.90)

    static let accentSoft = accent.opacity(0.14)
    static let successSoft = success.opacity(0.12)
    static let dangerSoft = danger.opacity(0.12)
    static let warningSoft = warning.opacity(0.12)
    static let infoSoft = info.opacity(0.12)

    static let canvas = Color(nsColor: .underPageBackgroundColor).opacity(0.98)
    static let surface = Color(nsColor: .controlBackgroundColor).opacity(0.96)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor).opacity(0.98)
    static let stroke = Color(nsColor: .separatorColor)
    static let muted = Color(nsColor: .secondaryLabelColor)

    static let heroGradient = LinearGradient(
        colors: [
            Color(nsColor: .windowBackgroundColor),
            Color(nsColor: .windowBackgroundColor)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let badgeGradient = LinearGradient(
        colors: [accent.opacity(0.9), accent.opacity(0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.heroGradient
        }
        .ignoresSafeArea()
    }
}

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.stroke.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
            )
    }
}

struct AppTag: View {
    let text: String
    let icon: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15))
        .foregroundColor(tint)
        .cornerRadius(999)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.badgeGradient)
                    .shadow(color: AppTheme.accent.opacity(0.18), radius: 10, x: 0, y: 6)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppPrimaryButtonStrongStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.accentStrong)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppSoftButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.18 : 0.12))
            )
    }
}
