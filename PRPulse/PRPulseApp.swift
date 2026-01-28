import SwiftUI

@main
struct PRPulseApp: App {
    @StateObject private var service = GitHubService()
    @State private var showingTokenSheet = false

    var body: some Scene {
        MenuBarExtra {
            PRListView(service: service, showingTokenSheet: $showingTokenSheet)
                .onAppear {
                    if TokenManager.shared.hasToken {
                        service.startPolling()
                    } else {
                        showSettingsWindow(showOnboarding: true)
                    }
                }
                .onChange(of: showingTokenSheet) { newValue in
                    if newValue {
                        showSettingsWindow(showOnboarding: false)
                        showingTokenSheet = false
                    }
                }
        } label: {
            MenuBarIcon(health: service.overallHealth, count: service.pullRequests.count)
        }
        .menuBarExtraStyle(.window)
    }

    private func showSettingsWindow(showOnboarding: Bool) {
        let service = self.service
        SettingsWindowController.shared.show(showOnboarding: showOnboarding) {
            service.startPolling()
        }
    }
}

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(showOnboarding: Bool, onSave: @escaping () -> Void) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view: AnyView
        if showOnboarding || !TokenManager.shared.hasToken {
            view = AnyView(
                OnboardingView()
                    .onDisappear {
                        onSave()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            self?.window?.close()
                        }
                    }
            )
        } else {
            view = AnyView(
                SettingsView {
                    onSave()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.window?.close()
                    }
                }
            )
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 700)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "PRPulse Setup"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        self.window = w
    }
}

struct MenuBarIcon: View {
    let health: CIStatus
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .symbolRenderingMode(.monochrome)
                .foregroundColor(iconColor)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
    }

    private var iconName: String {
        "arrow.triangle.pull"
    }

    private var iconColor: Color {
        switch health {
        case .success: return AppTheme.success
        case .failure: return AppTheme.danger
        case .pending: return AppTheme.warning
        case .unknown: return .primary
        }
    }
}
