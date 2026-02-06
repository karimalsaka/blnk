import SwiftUI

struct OnboardingBulletItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(AppTheme.accent.opacity(0.7))
                .frame(width: 5, height: 5)
                .offset(y: 1)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
