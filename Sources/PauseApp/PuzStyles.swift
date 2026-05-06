import SwiftUI

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
    @State private var flashOpacity: Double = 0.24
    @State private var ringOpacity: Double = 0.42
    @State private var ringScale: CGFloat = 0.74

    var body: some View {
        ZStack {
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()

            Circle()
                .stroke(.white.opacity(ringOpacity), lineWidth: 3)
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
