import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum AppTheme {
    // Minimal, light theme inspired by compact mobile lists
    static let accent = dynamic(
        light: NSColor(calibratedRed: 0.28, green: 0.34, blue: 0.82, alpha: 1),
        dark: NSColor(calibratedRed: 0.48, green: 0.54, blue: 0.92, alpha: 1)
    )
    static let accentStrong = dynamic(
        light: NSColor(calibratedRed: 0.20, green: 0.26, blue: 0.72, alpha: 1),
        dark: NSColor(calibratedRed: 0.36, green: 0.42, blue: 0.86, alpha: 1)
    )
    static let success = dynamic(
        light: NSColor(calibratedRed: 0.30, green: 0.68, blue: 0.44, alpha: 1),
        dark: NSColor(calibratedRed: 0.38, green: 0.76, blue: 0.52, alpha: 1)
    )
    static let danger = dynamic(
        light: NSColor(calibratedRed: 0.84, green: 0.40, blue: 0.40, alpha: 1),
        dark: NSColor(calibratedRed: 0.88, green: 0.46, blue: 0.46, alpha: 1)
    )
    static let warning = dynamic(
        light: NSColor(calibratedRed: 0.90, green: 0.68, blue: 0.24, alpha: 1),
        dark: NSColor(calibratedRed: 0.94, green: 0.74, blue: 0.32, alpha: 1)
    )
    static let info = dynamic(
        light: NSColor(calibratedRed: 0.36, green: 0.52, blue: 0.86, alpha: 1),
        dark: NSColor(calibratedRed: 0.46, green: 0.60, blue: 0.92, alpha: 1)
    )

    static let accentSoft = accent.opacity(0.14)
    static let successSoft = success.opacity(0.12)
    static let dangerSoft = danger.opacity(0.12)
    static let warningSoft = warning.opacity(0.12)
    static let infoSoft = info.opacity(0.12)

    static let canvas = dynamic(
        light: NSColor(calibratedWhite: 1.0, alpha: 1),
        dark: NSColor(calibratedWhite: 0.08, alpha: 1)
    )
    static let surface = dynamic(
        light: NSColor(calibratedWhite: 0.98, alpha: 1),
        dark: NSColor(calibratedWhite: 0.12, alpha: 1)
    )
    static let elevatedSurface = dynamic(
        light: NSColor(calibratedWhite: 0.99, alpha: 1),
        dark: NSColor(calibratedWhite: 0.1, alpha: 1)
    )
    static let stroke = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.05),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.08)
    )
    static let strokeStrong = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.10),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.16)
    )
    static let muted = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.52),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.60)
    )
    static let hoverOverlay = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.015),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.04)
    )
    static let cardShadow = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.05),
        dark: NSColor(calibratedWhite: 0.0, alpha: 0.45)
    )
    static let badgeGradient = LinearGradient(
        colors: [accent.opacity(0.85), accentStrong.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    #if canImport(AppKit)
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return dark
            }
            return light
        })
    }
    #else
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
    #endif
}

struct AppBackground: View {
    var body: some View {
        AppTheme.canvas
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
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
        .background(tint.opacity(0.12))
        .foregroundColor(tint)
        .cornerRadius(999)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppPrimaryButtonStrongStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.accentStrong)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppSoftButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.18 : 0.12))
            )
    }
}
