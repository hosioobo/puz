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
    var isComplete = false

    var body: some View {
        Image(systemName: isComplete ? "checkmark.circle" : symbolName)
            .font(.system(size: 48, weight: .regular))
            .foregroundStyle(PuzFullscreenTheme.accent)
            .symbolRenderingMode(.hierarchical)
    }

    private var symbolName: String {
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
            lineWidth: lineWidth
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

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var shouldFill: Bool {
        isEnabled && (isHovering || configuration.isPressed)
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
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
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

struct PuzEndSessionDialog: View {
    let canSnooze: Bool
    let onAction: (SessionEndAction) -> Void
    let onKeepGoing: () -> Void

    private let strings = PuzLocalization.current

    var body: some View {
        ZStack {
            Color.black.opacity(0.20)
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
                        let enabled = action != .remindMeLater || canSnooze
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
                                lineWidth: 1.5
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
                            lineWidth: 1.25
                        )
                    )
                    .focusable(false)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 38)
            .frame(width: 620)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .shadow(color: Color.black.opacity(0.18), radius: 34, x: 0, y: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(PuzFullscreenTheme.hairline.opacity(0.65), lineWidth: 1)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
