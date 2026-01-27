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
                        showSettingsWindow()
                    }
                }
                .onChange(of: showingTokenSheet) { newValue in
                    if newValue {
                        showSettingsWindow()
                        showingTokenSheet = false
                    }
                }
        } label: {
            MenuBarIcon(health: service.overallHealth, count: service.pullRequests.count)
        }
        .menuBarExtraStyle(.window)
    }

    private func showSettingsWindow() {
        let service = self.service
        SettingsWindowController.shared.show {
            service.startPolling()
        }
    }
}

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(onSave: @escaping () -> Void) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = TokenSettingsView(isPresented: .constant(true), onDismiss: { [weak self] in
            self?.window?.close()
        }, onSave: onSave)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 280)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "PRPulse Settings"
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
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
                .symbolRenderingMode(.palette)
                .foregroundStyle(iconColor, .primary)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
    }

    private var iconName: String {
        switch health {
        case .success: return "arrow.triangle.pull"
        case .failure: return "exclamationmark.arrow.triangle.2.circlepath"
        case .pending: return "arrow.triangle.pull"
        case .unknown: return "arrow.triangle.pull"
        }
    }

    private var iconColor: Color {
        switch health {
        case .success: return .green
        case .failure: return .red
        case .pending: return .orange
        case .unknown: return .secondary
        }
    }
}
