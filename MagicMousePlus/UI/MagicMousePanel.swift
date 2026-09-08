import SwiftUI

/// The visual control panel for Magic Mouse +.
///
/// This view intentionally owns no engine state. `AppModel` remains the single
/// source of truth for the tap engine, permissions, and login-item behavior.
struct MagicMousePanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let panelWidth: CGFloat = 740
    private let panelHeight: CGFloat = 740

    var body: some View {
        ZStack {
            MagicMouseTheme.background

            CRTScanlines(isDimmed: reduceMotion)

            VStack(spacing: 0) {

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        heroHeader
                        statusCard
                        controlGrid
                        permissionCard
                        eventLog
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer.padding(24)
            }
            .background(MagicMouseTheme.surface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MagicMouseTheme.border, lineWidth: 1)
            }
            .shadow(color: MagicMouseTheme.accent.opacity(0.16), radius: 24, y: 10)
            .padding(16)
        }
        .frame(minWidth: panelWidth, idealWidth: panelWidth, maxWidth: 760,
               minHeight: panelHeight, idealHeight: panelHeight, maxHeight: 820)
        .preferredColorScheme(.dark)
        .background(MagicMouseTheme.background)
    }

    private var heroHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            MouseMark()

            VStack(alignment: .leading, spacing: 6) {
                Text("MAGIC MOUSE +")
                    .font(MagicMouseTheme.title)
                    .tracking(1.4)
                    .foregroundStyle(MagicMouseTheme.primaryText)

                Text("TOUCH MORE.  DO MORE.")
                    .font(MagicMouseTheme.monoSmall)
                    .tracking(2)
                    .foregroundStyle(MagicMouseTheme.accent)

                Text("A small, private tap engine for macOS.")
                    .font(MagicMouseTheme.body)
                    .foregroundStyle(MagicMouseTheme.secondaryText)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text("NATIVE UTILITY")
                    .font(MagicMouseTheme.monoTiny)
                    .tracking(1.2)
                    .foregroundStyle(MagicMouseTheme.mutedText)

                Text("NO NETWORK")
                    .font(MagicMouseTheme.monoTiny)
                    .tracking(1.2)
                    .foregroundStyle(MagicMouseTheme.accent.opacity(0.9))
            }
        }
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MagicMouseTheme.rule)
                .frame(height: 1)
        }
    }

    private var statusCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "SYSTEM STATUS", symbol: "◈")

                HStack(alignment: .center, spacing: 14) {
                    StatusLamp(isActive: model.status == "ACTIVE")

                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.status)
                            .font(MagicMouseTheme.heading)
                            .foregroundStyle(model.status == "ACTIVE" ? MagicMouseTheme.accent : MagicMouseTheme.secondaryText)

                        Text(model.enabled ? "TAP TO CLICK ENABLED" : "TAP TO CLICK DISABLED")
                            .font(MagicMouseTheme.monoSmall)
                            .foregroundStyle(MagicMouseTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(model.deviceConnected ? "MAGIC MOUSE" : (model.permissionGranted && model.enabled ? "NO DEVICE" : "DEVICE"))
                            .font(MagicMouseTheme.monoSmall)
                            .foregroundStyle(model.deviceConnected ? MagicMouseTheme.primaryText : MagicMouseTheme.warning)

                        Text(model.deviceConnected ? "CONNECTED" : (model.permissionGranted && model.enabled ? "WAITING" : "NOT CHECKED"))
                            .font(MagicMouseTheme.monoTiny)
                            .foregroundStyle(MagicMouseTheme.secondaryText)
                    }
                }

                HStack(spacing: 8) {
                    SystemPill(label: model.permissionGranted ? "ACCESSIBILITY READY" : "ACCESSIBILITY NEEDED",
                               active: model.permissionGranted)

                    SystemPill(label: model.enabled ? "TAP ENGINE ON" : "TAP ENGINE OFF",
                               active: model.enabled)
                }
            }
        }
    }

    private var controlGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            PanelCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "TAP CONTROLS", symbol: "⌁")

                    TerminalToggleRow(
                        title: "TAP TO CLICK",
                        detail: "Enable surface taps",
                        isOn: Binding(
                            get: { model.enabled },
                            set: { model.enabled = $0 }
                        )
                    )

                    Rule()

                    TerminalToggleRow(
                        title: "LEFT TAP",
                        detail: "Left surface → click",
                        isOn: Binding(
                            get: { model.leftTap },
                            set: { model.leftTap = $0 }
                        )
                    )
                    .disabled(!model.enabled)

                    TerminalToggleRow(
                        title: "RIGHT TAP",
                        detail: "Right surface → right click",
                        isOn: Binding(
                            get: { model.rightTap },
                            set: { model.rightTap = $0 }
                        )
                    )
                    .disabled(!model.enabled)
                }
            }

            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "SURFACE MAP", symbol: "⌖")

                    MouseDiagram(leftEnabled: model.leftTap && model.enabled,
                                 rightEnabled: model.rightTap && model.enabled)
                        .frame(maxWidth: .infinity, minHeight: 164)

                    Text("Touch either side without pressure.")
                        .font(MagicMouseTheme.monoTiny)
                        .foregroundStyle(MagicMouseTheme.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var permissionCard: some View {
        PanelCard {
            HStack(alignment: .center, spacing: 14) {
                PermissionSeal(granted: model.permissionGranted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.permissionGranted ? "ACCESSIBILITY READY" : "ACCESSIBILITY PERMISSION")
                        .font(MagicMouseTheme.heading)
                        .foregroundStyle(MagicMouseTheme.primaryText)

                    Text(model.permissionGranted
                         ? (model.status == "INPUT ACCESS NEEDED" ? "Allow Input Monitoring to filter physical clicks." : "The tap engine can send native click events.")
                         : "Allow Accessibility access to send left and right clicks.")
                        .font(MagicMouseTheme.body)
                        .foregroundStyle(MagicMouseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if !model.permissionGranted || model.status == "INPUT ACCESS NEEDED" {
                    Button {
                        model.requestPermission()
                    } label: {
                        Text("ALLOW ACCESS")
                            .font(MagicMouseTheme.monoSmall)
                            .tracking(0.8)
                            .foregroundStyle(MagicMouseTheme.background)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(MagicMouseTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Request accessibility permission")
                }
            }
        }
    }

    private var eventLog: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "EVENT LOG", symbol: ">_")
                    Spacer()
                    Text("LOCAL ONLY")
                        .font(MagicMouseTheme.monoTiny)
                        .tracking(0.8)
                        .foregroundStyle(MagicMouseTheme.mutedText)
                }

                if model.logs.isEmpty {
                    LogLine(text: "waiting for engine events…", dimmed: true)
                } else {
                    ForEach(Array(model.logs.suffix(4).enumerated()), id: \.offset) { _, entry in
                        LogLine(text: entry, dimmed: false)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TerminalToggleRow(
                    title: "START AT LOGIN",
                    detail: "Open in the background",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLoginItem($0) }
                    )
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    model.hide()
                } label: {
                    Text("[ HIDE ]")
                        .font(MagicMouseTheme.monoSmall)
                        .foregroundStyle(MagicMouseTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(MagicMouseTheme.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide Magic Mouse Plus")

                Button {
                    model.quit()
                } label: {
                    Text("[ QUIT ]")
                        .font(MagicMouseTheme.monoSmall)
                        .foregroundStyle(MagicMouseTheme.warning)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(MagicMouseTheme.warning.opacity(0.7), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quit Magic Mouse Plus")
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11, weight: .medium))
                Text("No network • No analytics • Just your Mac")
            }
            .font(MagicMouseTheme.monoTiny)
            .foregroundStyle(MagicMouseTheme.mutedText)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 2)
    }
}

// MARK: - Reusable panel pieces

private struct MouseMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(MagicMouseTheme.accent.opacity(0.08))
                .frame(width: 54, height: 54)

            Path { path in
                path.move(to: CGPoint(x: 27, y: 12))
                path.addCurve(to: CGPoint(x: 17, y: 22),
                              control1: CGPoint(x: 27, y: 12),
                              control2: CGPoint(x: 17, y: 13))
                path.addLine(to: CGPoint(x: 17, y: 32))
                path.addCurve(to: CGPoint(x: 27, y: 42),
                              control1: CGPoint(x: 17, y: 40),
                              control2: CGPoint(x: 23, y: 42))
                path.addCurve(to: CGPoint(x: 37, y: 32),
                              control1: CGPoint(x: 31, y: 42),
                              control2: CGPoint(x: 37, y: 40))
                path.addLine(to: CGPoint(x: 37, y: 22))
                path.addCurve(to: CGPoint(x: 27, y: 12),
                              control1: CGPoint(x: 37, y: 13),
                              control2: CGPoint(x: 27, y: 12))
            }
            .stroke(MagicMouseTheme.primaryText, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

            Rectangle()
                .fill(MagicMouseTheme.primaryText)
                .frame(width: 1, height: 9)
                .offset(y: -11)

            Text("+")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(MagicMouseTheme.accent)
                .offset(x: 21, y: 18)
        }
        .frame(width: 54, height: 54)
        .accessibilityHidden(true)
    }
}

private struct PanelCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MagicMouseTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MagicMouseTheme.border.opacity(0.92), lineWidth: 1)
            }
    }
}

private struct SectionLabel: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Text(symbol)
                .foregroundStyle(MagicMouseTheme.accent)
            Text(text)
                .foregroundStyle(MagicMouseTheme.accent)
        }
        .font(MagicMouseTheme.monoSmall)
        .tracking(1.1)
    }
}

private struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(MagicMouseTheme.rule)
            .frame(height: 1)
    }
}

private struct StatusLamp: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? MagicMouseTheme.accent : MagicMouseTheme.mutedText)
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .stroke((isActive ? MagicMouseTheme.accent : MagicMouseTheme.mutedText).opacity(0.35), lineWidth: 5)
            }
            .accessibilityLabel(isActive ? "Active" : "Inactive")
    }
}

private struct SystemPill: View {
    let label: String
    let active: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? MagicMouseTheme.accent : MagicMouseTheme.mutedText)
                .frame(width: 5, height: 5)
            Text(label)
        }
        .font(MagicMouseTheme.monoTiny)
        .foregroundStyle(active ? MagicMouseTheme.accent : MagicMouseTheme.mutedText)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(MagicMouseTheme.background.opacity(0.75), in: Capsule())
        .overlay(Capsule().stroke(MagicMouseTheme.border, lineWidth: 1))
    }
}

private struct PermissionSeal: View {
    let granted: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(granted ? MagicMouseTheme.accent : MagicMouseTheme.warning, lineWidth: 1)
                .frame(width: 38, height: 38)
            Image(systemName: granted ? "checkmark" : "lock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(granted ? MagicMouseTheme.accent : MagicMouseTheme.warning)
        }
        .accessibilityHidden(true)
    }
}

private struct TerminalToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MagicMouseTheme.monoSmall)
                        .foregroundStyle(MagicMouseTheme.primaryText)
                    Text(detail)
                        .font(MagicMouseTheme.monoTiny)
                        .foregroundStyle(MagicMouseTheme.mutedText)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    Text(isOn ? "ON" : "OFF")
                        .font(MagicMouseTheme.monoTiny)
                        .foregroundStyle(isOn ? MagicMouseTheme.accent : MagicMouseTheme.mutedText)

                    ZStack(alignment: isOn ? .trailing : .leading) {
                        Capsule()
                            .fill(isOn ? MagicMouseTheme.accent.opacity(0.22) : MagicMouseTheme.background)
                            .frame(width: 38, height: 20)
                            .overlay(Capsule().stroke(isOn ? MagicMouseTheme.accent : MagicMouseTheme.border, lineWidth: 1))

                        Circle()
                            .fill(isOn ? MagicMouseTheme.accent : MagicMouseTheme.mutedText)
                            .frame(width: 14, height: 14)
                            .padding(3)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isOn)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

private struct LogLine: View {
    let text: String
    let dimmed: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(">")
                .foregroundStyle(MagicMouseTheme.accent)
            Text(text)
                .foregroundStyle(dimmed ? MagicMouseTheme.mutedText : MagicMouseTheme.secondaryText)
                .lineLimit(1)
        }
        .font(MagicMouseTheme.monoTiny)
    }
}

private struct MouseDiagram: View {
    let leftEnabled: Bool
    let rightEnabled: Bool

    var body: some View {
        GeometryReader { proxy in
            let mouseWidth = min(proxy.size.width * 0.42, 106)
            let mouseHeight = min(proxy.size.height * 0.88, 150)
            let centerX = proxy.size.width / 2
            let leftX = centerX - mouseWidth / 2
            let rightX = centerX + mouseWidth / 2
            let midY = proxy.size.height / 2

            ZStack {
                RoundedRectangle(cornerRadius: mouseWidth * 0.47, style: .continuous)
                    .fill(MagicMouseTheme.background.opacity(0.62))
                    .frame(width: mouseWidth, height: mouseHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: mouseWidth * 0.47, style: .continuous)
                            .stroke(MagicMouseTheme.accent, lineWidth: 1.2)
                    }

                Rectangle()
                    .fill(MagicMouseTheme.accent.opacity(0.7))
                    .frame(width: 1, height: mouseHeight * 0.45)
                    .offset(y: -mouseHeight * 0.12)

                Rectangle()
                    .fill(MagicMouseTheme.rule)
                    .frame(width: mouseWidth * 0.52, height: 1)
                    .offset(y: -mouseHeight * 0.28)

                SurfaceIndicator(active: leftEnabled)
                    .position(x: leftX + mouseWidth * 0.25, y: midY + 4)
                SurfaceIndicator(active: rightEnabled)
                    .position(x: rightX - mouseWidth * 0.25, y: midY + 4)

                SurfaceLabel(text: "LEFT", active: leftEnabled)
                    .position(x: max(28, leftX - 25), y: midY + 4)
                SurfaceLabel(text: "RIGHT", active: rightEnabled)
                    .position(x: min(proxy.size.width - 30, rightX + 30), y: midY + 4)

                Text("+")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(MagicMouseTheme.accent)
                    .position(x: centerX, y: midY + mouseHeight * 0.29)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Magic Mouse surface map")
        .accessibilityValue("Left tap \(leftEnabled ? "enabled" : "disabled"); right tap \(rightEnabled ? "enabled" : "disabled")")
    }
}

private struct SurfaceIndicator: View {
    let active: Bool

    var body: some View {
        Circle()
            .fill(active ? MagicMouseTheme.accent : MagicMouseTheme.mutedText)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(MagicMouseTheme.background, lineWidth: 2))
    }
}

private struct SurfaceLabel: View {
    let text: String
    let active: Bool

    var body: some View {
        Text(text)
            .font(MagicMouseTheme.monoTiny)
            .foregroundStyle(active ? MagicMouseTheme.accent : MagicMouseTheme.mutedText)
    }
}

private struct CRTScanlines: View {
    let isDimmed: Bool

    var body: some View {
        Canvas { context, size in
            var lines = Path()
            for y in stride(from: 0.0, to: size.height, by: 6.0) {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(.white.opacity(isDimmed ? 0.008 : 0.018)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum MagicMouseTheme {
    static let background = Color(red: 0.015, green: 0.025, blue: 0.026)
    static let surface = Color(red: 0.025, green: 0.055, blue: 0.052)
    static let card = Color(red: 0.025, green: 0.072, blue: 0.065)
    static let chrome = Color(red: 0.045, green: 0.075, blue: 0.074)

    static let accent = Color(red: 0.22, green: 0.95, blue: 0.55)
    static let primaryText = Color(red: 0.86, green: 0.94, blue: 0.91)
    static let secondaryText = Color(red: 0.56, green: 0.67, blue: 0.64)
    static let mutedText = Color(red: 0.49, green: 0.62, blue: 0.57)
    static let warning = Color(red: 1.0, green: 0.37, blue: 0.32)

    static let border = Color(red: 0.18, green: 0.36, blue: 0.32)
    static let rule = Color(red: 0.12, green: 0.29, blue: 0.24)

    static let title = Font.system(size: 22, weight: .semibold, design: .monospaced)
    static let heading = Font.system(size: 15, weight: .medium, design: .monospaced)
    static let body = Font.system(size: 12, weight: .regular, design: .default)
    static let monoSmall = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let monoTiny = Font.system(size: 11, weight: .regular, design: .monospaced)
}
