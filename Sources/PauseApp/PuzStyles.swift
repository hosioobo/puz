import AppKit
import SwiftUI
import PauseCore

/// Shared visual tokens for the light fullscreen flow.
enum PuzFullscreenTheme {
    static let accent = Color(red: 0.04, green: 0.42, blue: 0.95)
    static let text = Color(red: 0.07, green: 0.09, blue: 0.12)
    static let secondaryText = Color(red: 0.37, green: 0.38, blue: 0.42)
    static let mutedText = Color(red: 0.50, green: 0.51, blue: 0.55)
    static let hairline = Color(red: 0.78, green: 0.80, blue: 0.84)
    static let ringTrack = Color(red: 0.84, green: 0.85, blue: 0.89)
    static let dialogSurface = Color(red: 1.0, green: 0.992, blue: 0.976)
}

enum PuzKeyboardCommand {
    case confirm
    case moveNext
    case movePrevious
    case cancel

    init?(event: NSEvent) {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blockedModifiers).isEmpty else { return nil }

        switch event.keyCode {
        case 36, 76:
            self = .confirm
        case 124, 125:
            self = .moveNext
        case 123, 126:
            self = .movePrevious
        case 53:
            self = .cancel
        default:
            return nil
        }
    }
}

private struct PuzKeyboardShortcutReader: NSViewRepresentable {
    let onCommand: (PuzKeyboardCommand) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onCommand: onCommand)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.onCommand = onCommand
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var onCommand: (PuzKeyboardCommand) -> Bool
        weak var view: NSView?
        private var monitor: Any?

        init(onCommand: @escaping (PuzKeyboardCommand) -> Bool) {
            self.onCommand = onCommand
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      self.view?.window?.isKeyWindow == true,
                      let command = PuzKeyboardCommand(event: event)
                else {
                    return event
                }
                return self.onCommand(command) ? nil : event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit {
            removeMonitor()
        }
    }
}

extension View {
    func puzKeyboardShortcuts(_ onCommand: @escaping (PuzKeyboardCommand) -> Bool) -> some View {
        background(
            PuzKeyboardShortcutReader(onCommand: onCommand)
                .frame(width: 0, height: 0)
        )
    }
}

struct PuzFullscreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.995, green: 0.988, blue: 0.976),
                Color(red: 0.972, green: 0.956, blue: 0.932)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct PuzBrandLockup: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("<//>")
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
            Text("puz")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(PuzFullscreenTheme.accent)
    }
}

struct PuzRoutineGlyph: View {
    let actionType: ActionType
    var symbolName: String? = nil
    var isComplete = false

    var body: some View {
        Image(systemName: isComplete ? "checkmark.circle" : resolvedSymbolName)
            .font(.system(size: 48, weight: .regular))
            .foregroundStyle(PuzFullscreenTheme.accent)
            .symbolRenderingMode(.hierarchical)
    }

    private var resolvedSymbolName: String {
        let trimmedSymbolName = symbolName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedSymbolName, !trimmedSymbolName.isEmpty {
            return trimmedSymbolName
        }

        switch actionType {
        case .burpee, .exercise:
            return "figure.walk"
        case .standUp:
            return "figure.stand"
        case .drinkWater:
            return "drop"
        case .stretch:
            return "figure.walk"
        case .eyeRest:
            return "eye"
        }
    }
}

struct PuzInfoLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 22, weight: .regular))
            Text(text)
                .font(.system(size: 21, weight: .medium, design: .rounded))
        }
        .foregroundStyle(PuzFullscreenTheme.mutedText)
    }
}

struct PuzBigButtonStyle: ButtonStyle {
    var accent: Color = .white
    var foreground: Color? = nil
    var filledForeground: Color = .black
    var hoverFill: Color? = nil
    var minWidth: CGFloat = 220
    var minHeight: CGFloat = 82
    var fontSize: CGFloat = 32
    var horizontalPadding: CGFloat = 24
    var cornerRadius: CGFloat = 24
    var lineWidth: CGFloat = 2
    var isKeyboardFocused = false

    func makeBody(configuration: Configuration) -> some View {
        PuzBigButtonBody(
            configuration: configuration,
            accent: accent,
            foreground: foreground ?? accent,
            filledForeground: filledForeground,
            hoverFill: hoverFill ?? accent,
            minWidth: minWidth,
            minHeight: minHeight,
            fontSize: fontSize,
            horizontalPadding: horizontalPadding,
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            isKeyboardFocused: isKeyboardFocused
        )
    }
}

private struct PuzBigButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let accent: Color
    let foreground: Color
    let filledForeground: Color
    let hoverFill: Color
    let minWidth: CGFloat
    let minHeight: CGFloat
    let fontSize: CGFloat
    let horizontalPadding: CGFloat
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let isKeyboardFocused: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var shouldFill: Bool {
        isEnabled && (isHovering || configuration.isPressed)
    }

    private var showsKeyboardFocus: Bool {
        isEnabled && isKeyboardFocused
    }

    var body: some View {
        configuration.label
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .frame(minWidth: minWidth, minHeight: minHeight)
            .padding(.horizontal, horizontalPadding)
            .foregroundStyle((shouldFill ? filledForeground : foreground).opacity(isEnabled ? 1 : 0.42))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(hoverFill.opacity(shouldFill ? (configuration.isPressed ? 0.76 : 1) : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(isEnabled ? 0.86 : 0.28), lineWidth: lineWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius + 5, style: .continuous)
                    .stroke(accent.opacity(showsKeyboardFocus ? 0.78 : 0), lineWidth: 3)
                    .padding(-5)
            )
            .shadow(color: accent.opacity(showsKeyboardFocus ? 0.18 : 0), radius: 14, x: 0, y: 0)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.12), value: showsKeyboardFocus)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct PuzEntranceFlash: View {
    var tint: Color = PuzFullscreenTheme.accent
    @State private var flashOpacity: Double = 0.12
    @State private var ringOpacity: Double = 0.34
    @State private var ringScale: CGFloat = 0.74

    var body: some View {
        ZStack {
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()

            Circle()
                .stroke(tint.opacity(ringOpacity), lineWidth: 3)
                .frame(width: 420, height: 420)
                .scaleEffect(ringScale)
                .blur(radius: 0.5)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.46)) {
                flashOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.62)) {
                ringOpacity = 0
                ringScale = 1.18
            }
        }
    }
}

private enum PuzEndSessionDialogTarget: Hashable {
    case action(SessionEndAction)
    case keepGoing
}

struct PuzEndSessionDialog: View {
    let canSnooze: Bool
    let onAction: (SessionEndAction) -> Void
    let onKeepGoing: () -> Void

    @State private var selectedKeyboardTarget: PuzEndSessionDialogTarget = .action(.remindMeLater)

    private let strings = PuzLocalization.current

    private var keyboardTargets: [PuzEndSessionDialogTarget] {
        var targets = SessionEndAction.allCases
            .filter(isActionEnabled)
            .map(PuzEndSessionDialogTarget.action)
        targets.append(.keepGoing)
        return targets
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text(strings.endSessionTitle)
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.text)
                        .multilineTextAlignment(.center)

                    Text(strings.endSessionMessage)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    ForEach(SessionEndAction.allCases, id: \.self) { action in
                        let enabled = isActionEnabled(action)
                        Button { onAction(action) } label: {
                            VStack(spacing: 4) {
                                Text(strings.endSessionActionTitle(action))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                Text(strings.endSessionActionSubtitle(action, canSnooze: canSnooze))
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(enabled ? PuzFullscreenTheme.secondaryText : PuzFullscreenTheme.mutedText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .disabled(!enabled)
                        .buttonStyle(
                            PuzBigButtonStyle(
                                accent: action == .skipToday ? PuzFullscreenTheme.text : PuzFullscreenTheme.accent,
                                foreground: action == .skipToday ? PuzFullscreenTheme.text : PuzFullscreenTheme.accent,
                                filledForeground: .white,
                                hoverFill: action == .skipToday ? PuzFullscreenTheme.text : PuzFullscreenTheme.accent,
                                minWidth: 500,
                                minHeight: 74,
                                fontSize: 23,
                                cornerRadius: 18,
                                lineWidth: 1.5,
                                isKeyboardFocused: selectedKeyboardTarget == .action(action)
                            )
                        )
                    }
                }

                Button(strings.endSessionKeepGoingTitle) { onKeepGoing() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(
                        PuzBigButtonStyle(
                            accent: PuzFullscreenTheme.hairline,
                            foreground: PuzFullscreenTheme.secondaryText,
                            filledForeground: PuzFullscreenTheme.text,
                            hoverFill: PuzFullscreenTheme.hairline.opacity(0.18),
                            minWidth: 240,
                            minHeight: 54,
                            fontSize: 18,
                            cornerRadius: 16,
                            lineWidth: 1.25,
                            isKeyboardFocused: selectedKeyboardTarget == .keepGoing
                        )
                    )
                    .focusable(false)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 38)
            .frame(width: 620)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(PuzFullscreenTheme.dialogSurface)
                    .shadow(color: Color.black.opacity(0.18), radius: 34, x: 0, y: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(PuzFullscreenTheme.hairline.opacity(0.65), lineWidth: 1)
            )
        }
        .onAppear(perform: normalizeKeyboardSelection)
        .onChange(of: canSnooze) { _ in normalizeKeyboardSelection() }
        .puzKeyboardShortcuts { handleKeyboardCommand($0) }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func isActionEnabled(_ action: SessionEndAction) -> Bool {
        action != .remindMeLater || canSnooze
    }

    private func normalizeKeyboardSelection() {
        guard !keyboardTargets.contains(selectedKeyboardTarget), let firstTarget = keyboardTargets.first else { return }
        selectedKeyboardTarget = firstTarget
    }

    private func moveKeyboardSelection(forward: Bool) {
        guard !keyboardTargets.isEmpty else { return }
        guard let currentIndex = keyboardTargets.firstIndex(of: selectedKeyboardTarget) else {
            selectedKeyboardTarget = keyboardTargets[0]
            return
        }

        let offset = forward ? 1 : -1
        selectedKeyboardTarget = keyboardTargets[(currentIndex + offset + keyboardTargets.count) % keyboardTargets.count]
    }

    private func activateKeyboardSelection() {
        switch selectedKeyboardTarget {
        case .action(let action) where isActionEnabled(action):
            onAction(action)
        case .keepGoing:
            onKeepGoing()
        default:
            normalizeKeyboardSelection()
        }
    }

    private func handleKeyboardCommand(_ command: PuzKeyboardCommand) -> Bool {
        switch command {
        case .confirm:
            activateKeyboardSelection()
            return true
        case .moveNext:
            moveKeyboardSelection(forward: true)
            return true
        case .movePrevious:
            moveKeyboardSelection(forward: false)
            return true
        case .cancel:
            onKeepGoing()
            return true
        }
    }
}
