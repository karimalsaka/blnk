import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum AppTheme {
    // Dark-first theme: true black canvas + soft, low-glare contrast.
    static let accent = dynamic(
        light: NSColor(calibratedRed: 0.28, green: 0.34, blue: 0.82, alpha: 1),
        dark: NSColor(calibratedRed: 0.54, green: 0.62, blue: 0.98, alpha: 1)
    )
    static let accentStrong = dynamic(
        light: NSColor(calibratedRed: 0.20, green: 0.26, blue: 0.72, alpha: 1),
        dark: NSColor(calibratedRed: 0.38, green: 0.46, blue: 0.92, alpha: 1)
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
    static let textPrimary = dynamic(
        light: NSColor(calibratedWhite: 0.08, alpha: 1),
        dark: NSColor(calibratedWhite: 0.86, alpha: 1)
    )

    static let accentSoft = accent.opacity(0.14)
    static let successSoft = success.opacity(0.12)
    static let dangerSoft = danger.opacity(0.12)
    static let warningSoft = warning.opacity(0.12)
    static let infoSoft = info.opacity(0.12)

    static let canvas = dynamic(
        light: NSColor(calibratedWhite: 1.0, alpha: 1),
        dark: NSColor(calibratedWhite: 0.04, alpha: 1)
    )
    static let surface = dynamic(
        light: NSColor(calibratedWhite: 0.98, alpha: 1),
        dark: NSColor(calibratedWhite: 0.086, alpha: 1)
    )
    static let cardSurface = dynamic(
        light: NSColor(calibratedWhite: 0.98, alpha: 1),
        dark: NSColor(calibratedWhite: 0.074, alpha: 1)
    )
    static let elevatedSurface = dynamic(
        light: NSColor(calibratedWhite: 0.99, alpha: 1),
        dark: NSColor(calibratedWhite: 0.118, alpha: 1)
    )
    static let stroke = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.05),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.10)
    )
    static let strokeStrong = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.10),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.18)
    )
    static let muted = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.52),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.60)
    )
    static let hoverOverlay = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.015),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.055)
    )
    static let cardShadow = dynamic(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.05),
        dark: NSColor(calibratedWhite: 0.0, alpha: 0.65)
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
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
            )
            .shadow(color: AppTheme.cardShadow.opacity(0.35), radius: 10, x: 0, y: 6)
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
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppTheme.stroke.opacity(0.9), lineWidth: 1)
                )
        )
        .foregroundColor(tint)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(Color.white.opacity(0.92))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accent.opacity(configuration.isPressed ? 0.85 : 0.95),
                                AppTheme.accentStrong.opacity(configuration.isPressed ? 0.85 : 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .shadow(color: AppTheme.cardShadow.opacity(0.35), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct AppPrimaryButtonStrongStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(Color.white.opacity(0.92))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accentStrong.opacity(configuration.isPressed ? 0.88 : 1.0),
                                AppTheme.accentStrong.opacity(configuration.isPressed ? 0.78 : 0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .shadow(color: AppTheme.cardShadow.opacity(0.35), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct AppSoftButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(tint.opacity(0.92))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.elevatedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(configuration.isPressed ? 0.14 : 0.08))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct AppToolbarButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(tint.opacity(configuration.isPressed ? 0.86 : 0.94))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.14 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(configuration.isPressed ? 0.34 : 0.24), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct AppInlineSpinner: View {
    let tint: Color
    let size: CGFloat
    let lineWidth: CGFloat
    @State private var rotationDegrees: Double = 0
    @State private var pulse = false

    init(tint: Color = AppTheme.accent, size: CGFloat = 12, lineWidth: CGFloat = 2) {
        self.tint = tint
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.stroke.opacity(0.9), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tint.opacity(pulse ? 0.22 : 0.14), tint.opacity(pulse ? 1.0 : 0.92)]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(rotationDegrees))
        }
        .frame(width: size, height: size)
        .onAppear {
            rotationDegrees = 0
            pulse = false
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotationDegrees = 360
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityLabel("Loading")
    }
}

struct AppDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.strokeStrong)
            .frame(height: 1)
            .opacity(0.85)
    }
}
