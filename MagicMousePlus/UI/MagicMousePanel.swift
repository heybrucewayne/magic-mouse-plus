import SwiftUI

struct MagicMousePanel: View {
    @ObservedObject var model: AppModel

    private var needsPermission: Bool {
        !model.permissionGranted || model.status == "INPUT ACCESS NEEDED"
    }
    private var status: String {
        if !model.enabled { return "Paused" }
        if needsPermission { return "Permission required" }
        if model.status == "ACTIVE" { return "Ready to tap" }
        if model.status == "SLEEPING" { return "Sleeping" }
        return model.deviceConnected ? "Connecting…" : "Connect your Magic Mouse"
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Magic Mouse +")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Circle().fill(model.status == "ACTIVE" ? Color.white : Color.gray)
                    .frame(width: 6, height: 6)
                Text(status).font(.system(size: 12)).foregroundStyle(.secondary)
            }

            HStack(spacing: 30) {
                mouse
                    .frame(width: 140, height: 200)
                VStack(alignment: .leading, spacing: 10) {
                    Text("A lighter touch.")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("Tap the surface to click.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            VStack(spacing: 0) {
                setting("Tap to click", symbol: "hand.tap", isOn: $model.enabled)
                rule
                setting("Left tap", symbol: "computermouse", isOn: $model.leftTap)
                    .disabled(!model.enabled)
                    .opacity(model.enabled ? 1 : 0.4)
                rule
                setting("Right tap", symbol: "cursorarrow.click.2", isOn: $model.rightTap)
                    .disabled(!model.enabled)
                    .opacity(model.enabled ? 1 : 0.4)
            }
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08)))

            if needsPermission {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield").font(.system(size: 19))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.status == "INPUT ACCESS NEEDED" ? "Input Monitoring" : "Accessibility")
                            .font(.system(size: 13, weight: .medium))
                        Text("Allow access to enable taps.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") { model.requestPermission() }
                        .buttonStyle(SoftButton(primary: true))
                }
                .padding(16)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            }

            setting("Start at login", symbol: "power",
                    isOn: Binding(get: { model.launchAtLogin }, set: { model.setLoginItem($0) }))
                .padding(.horizontal, -16)

            HStack {
                Button("Quit") { model.quit() }
                    .buttonStyle(SoftButton(primary: false))
                Spacer()
                Button("Done") { model.hide() }
                    .buttonStyle(SoftButton(primary: true))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Hide Magic Mouse Plus")
            }
        }
        .padding(30)
        .frame(width: 560)
        .frame(minHeight: 620)
        .background(Color(white: 0.055))
        .foregroundStyle(Color(white: 0.94))
        .preferredColorScheme(.dark)
    }

    private var rule: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1).padding(.leading, 48)
    }

    private func setting(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.6))
                .frame(width: 20)
            Toggle(title, isOn: isOn)
                .font(.system(size: 14, weight: .medium))
                .toggleStyle(MonochromeSwitch())
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
    }

    private var mouse: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 62, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.97), Color(white: 0.67)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 62).stroke(Color.white.opacity(0.8), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 14)
            HStack(spacing: 30) {
                Circle().fill(Color.black.opacity(model.enabled && model.leftTap ? 0.7 : 0.12))
                Circle().fill(Color.black.opacity(model.enabled && model.rightTap ? 0.7 : 0.12))
            }
            .frame(width: 46, height: 8)
            .padding(.top, 43)
            Rectangle().fill(Color.black.opacity(0.1))
                .frame(width: 1, height: 66)
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color.black.opacity(0.3))
                .padding(.top, 146)
        }
        .frame(width: 116, height: 184)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Magic Mouse. Left tap \(model.enabled && model.leftTap ? "enabled" : "disabled"), right tap \(model.enabled && model.rightTap ? "enabled" : "disabled").")
    }
}

private struct MonochromeSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer(minLength: 16)
                Capsule()
                    .fill(configuration.isOn ? Color(white: 0.94) : Color(white: 0.23))
                    .frame(width: 38, height: 23)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? Color(white: 0.08) : Color(white: 0.65))
                            .frame(width: 17, height: 17).padding(3)
                    }
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}

private struct SoftButton: ButtonStyle {
    var primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(primary ? Color.black : Color(white: 0.7))
            .background(primary ? Color(white: configuration.isPressed ? 0.72 : 0.94) :
                            Color.white.opacity(configuration.isPressed ? 0.12 : 0.055),
                        in: RoundedRectangle(cornerRadius: 10))
    }
}
