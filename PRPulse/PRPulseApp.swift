import SwiftUI
import Combine

@main
struct PRPulseApp: App {
    @StateObject private var service = GitHubService()
    @State private var showingTokenSheet = false
    @State private var hasToken = TokenManager.shared.hasToken
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
    }

    var body: some Scene {
        MenuBarExtra {
            Group {
                if hasToken {
                    PRListView(service: service, showingTokenSheet: $showingTokenSheet)
                } else {
                    SetupRequiredView {
                        showingTokenSheet = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .prefetchPRData)) { _ in
                if hasToken && !service.isLoading {
                    service.fetch()
                }
            }
            .onAppear {
                hasToken = TokenManager.shared.hasToken
                if hasToken {
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
            self.hasToken = TokenManager.shared.hasToken
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

        let shouldShowOnboarding = showOnboarding || !TokenManager.shared.hasToken
        let view: AnyView
        if shouldShowOnboarding {
            view = AnyView(
                OnboardingView(onComplete: {
                    onSave()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.window?.close()
                    }
                })
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

        let onboardingSize = NSSize(width: 720, height: 900)
        let settingsSize = NSSize(width: 600, height: 700)
        let windowSize = shouldShowOnboarding ? onboardingSize : settingsSize

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: windowSize)

        let styleMask: NSWindow.StyleMask = shouldShowOnboarding ? [.titled, .fullSizeContentView] : [.titled, .closable]
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        if shouldShowOnboarding {
            w.isMovableByWindowBackground = true
            w.standardWindowButton(.closeButton)?.isHidden = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
        }
        w.title = "blnk Setup"
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

private struct SetupRequiredView: View {
    let onOpenSetup: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 12) {
                Text("Finish setup to view PRs")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Button("Open Setup") {
                    onOpenSetup()
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
            .padding(20)
        }
        .frame(width: 320, height: 180)
        .background(AppTheme.canvas)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mouseMonitor: Any?
    private var lastPrefetchTime: Date = .distantPast
    private let prefetchCooldown: TimeInterval = 30 // Don't prefetch more than once per 30 seconds
    private var isInMenuBarArea: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
#if canImport(AppKit)
        NSApp.appearance = NSAppearance(named: .darkAqua)
#endif
        if !TokenManager.shared.hasToken {
            DispatchQueue.main.async {
                SettingsWindowController.shared.show(showOnboarding: true) {}
            }
        }

        setupMenuBarHoverMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupMenuBarHoverMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return }

            // Check if mouse is in menu bar area (top 24 pixels of screen)
            guard let screen = NSScreen.main else { return }
            let mouseY = event.locationInWindow.y
            let screenHeight = screen.frame.height
            let menuBarHeight: CGFloat = 24

            let wasInMenuBar = self.isInMenuBarArea
            self.isInMenuBarArea = mouseY >= screenHeight - menuBarHeight

            // Only trigger when first entering the menu bar area
            if self.isInMenuBarArea && !wasInMenuBar {
                self.triggerPrefetchIfNeeded()
            }
        }
    }

    private func triggerPrefetchIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastPrefetchTime) > prefetchCooldown else {
            print("[Prefetch] Skipped - cooldown active (\(Int(prefetchCooldown - now.timeIntervalSince(lastPrefetchTime)))s remaining)")
            return
        }
        guard TokenManager.shared.hasToken else {
            print("[Prefetch] Skipped - no token")
            return
        }

        print("[Prefetch] Triggered - mouse in menu bar area")
        lastPrefetchTime = now
        NotificationCenter.default.post(name: .prefetchPRData, object: nil)
    }
}

extension Notification.Name {
    static let prefetchPRData = Notification.Name("prefetchPRData")
}
