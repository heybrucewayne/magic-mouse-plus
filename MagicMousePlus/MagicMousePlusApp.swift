import SwiftUI
import AppKit
import ServiceManagement

@main struct MagicMousePlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Finder can launch copies from both Applications and DerivedData.
        // Only one process may own the touch stream and its TCC identity.
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated })
            .sorted(by: { $0.processIdentifier < $1.processIdentifier }).first {
            existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        refreshLoginItemLocationIfNeeded()
        model = AppModel()
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin { showPanel() }
    }
    private func refreshLoginItemLocationIfNeeded() {
        let currentPath = Bundle.main.bundleURL.standardizedFileURL.path
        let defaults = UserDefaults.standard
        let previousPath = defaults.string(forKey: "loginItemBundlePath")
        let iconRefreshVersion = 2

        // Moving the app changes the bundle path but can leave the existing
        // SMAppService record pointing at the old copy and its cached icon.
        let pathChanged = previousPath != currentPath
        let iconNeedsRefresh = defaults.integer(forKey: "loginItemIconRefreshVersion") < iconRefreshVersion
        guard pathChanged || iconNeedsRefresh else { return }
        guard SMAppService.mainApp.status == .enabled || previousPath != nil else {
            defaults.set(currentPath, forKey: "loginItemBundlePath")
            return
        }
        do {
            try? SMAppService.mainApp.unregister()
            try SMAppService.mainApp.register()
            defaults.set(currentPath, forKey: "loginItemBundlePath")
            defaults.set(iconRefreshVersion, forKey: "loginItemIconRefreshVersion")
        } catch {
            // Keep the old marker so the next launch retries the refresh.
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        // Returning from System Settings after changing Accessibility or
        // Input Monitoring must rebuild any stale TCC/event-tap session.
        TapEngine.shared.refresh()
    }
    private func showPanel() {
        if window == nil, let model {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 660),
                                 styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            panel.title = "Magic Mouse +"
            panel.contentView = NSHostingView(rootView: MagicMousePanel(model: model))
            panel.isReleasedWhenClosed = false; panel.delegate = self
            panel.titlebarAppearsTransparent = true
            panel.backgroundColor = NSColor(white: 0.055, alpha: 1)
            panel.center(); window = panel
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { TapEngine.shared.shutdown() }
}
