import SwiftUI
import AppKit

@main struct MagicMousePlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin { showPanel() }
    }
    private func showPanel() {
        if window == nil, let model {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 780),
                                 styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            panel.title = "Magic Mouse +"
            panel.contentView = NSHostingView(rootView: MagicMousePanel(model: model))
            panel.isReleasedWhenClosed = false; panel.delegate = self
            panel.titlebarAppearsTransparent = true
            panel.backgroundColor = NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.045, alpha: 1)
            panel.center(); window = panel
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { TapEngine.shared.shutdown() }
}
