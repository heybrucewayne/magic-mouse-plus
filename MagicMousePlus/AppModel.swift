import AppKit
import Combine
import ServiceManagement
import ApplicationServices

@MainActor final class AppModel: ObservableObject {
    @Published var enabled: Bool { didSet { save() } }
    @Published var leftTap: Bool { didSet { save() } }
    @Published var rightTap: Bool { didSet { save() } }
    @Published private(set) var launchAtLogin = false
    @Published private(set) var status = "INITIALIZING"
    @Published private(set) var deviceConnected = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var logs: [String] = []
    private let defaults = UserDefaults.standard
    init() {
        defaults.register(defaults: ["enabled": true, "leftTap": true, "rightTap": true])
        enabled = defaults.bool(forKey: "enabled")
        leftTap = defaults.bool(forKey: "leftTap"); rightTap = defaults.bool(forKey: "rightTap")
        launchAtLogin = SMAppService.mainApp.status == .enabled
        TapEngine.shared.onStatus = { [weak self] status, connected in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if self.permissionGranted != trusted { self.permissionGranted = trusted }
            if self.deviceConnected != connected { self.deviceConnected = connected }
            let login = SMAppService.mainApp.status == .enabled
            if self.launchAtLogin != login { self.launchAtLogin = login }
            if self.status != status { self.status = status; self.log(status.lowercased()) }
        }
        TapEngine.shared.configure(enabled: enabled, left: leftTap, right: rightTap)
        TapEngine.shared.start()
    }
    private func save() {
        defaults.set(enabled, forKey: "enabled"); defaults.set(leftTap, forKey: "leftTap"); defaults.set(rightTap, forKey: "rightTap")
        TapEngine.shared.configure(enabled: enabled, left: leftTap, right: rightTap)
    }
    private func log(_ message: String) {
        // Bounded, in-memory lifecycle log. Never records pointer positions or input.
        logs.append(message); if logs.count > 4 { logs.removeFirst(logs.count-4) }
    }
    func requestPermission() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        }
        // The user grants TCC permissions outside the app. Refreshing here
        // handles the case where the settings window returns before the
        // periodic check observes the new trust state; refresh() also forces
        // a clean event-tap/device session when the trust bit changed.
        TapEngine.shared.refresh()
    }
    func setLoginItem(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                log("login item needs approval in System Settings")
                SMAppService.openSystemSettingsLoginItems()
            } else { log(launchAtLogin ? "start at login enabled" : "start at login disabled") }
        } catch { launchAtLogin = SMAppService.mainApp.status == .enabled; log("login item: \(error.localizedDescription)") }
        // Registering or removing the login item can make macOS refresh the
        // app's launch/security state. Recheck the capture session immediately
        // so a login-item change cannot leave the running app inert.
        TapEngine.shared.refresh()
    }
    func hide() { NSApp.hide(nil) }
    func quit() { NSApp.terminate(nil) }
}
