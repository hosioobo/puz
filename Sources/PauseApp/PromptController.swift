import AppKit
import SwiftUI
import PauseCore

final class PromptController {
    private var windows: [NSWindow] = []

    func show(
        routine: Routine,
        scheduledDate: Date,
        usedSnoozeCount: Int,
        onStart: @escaping () -> Void,
        onSnooze: @escaping (SnoozeDelayOption) -> Void,
        onCancel: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        dismiss()

        for screen in NSScreen.screens {
            let view = PromptView(
                routine: routine,
                scheduledDate: scheduledDate,
                usedSnoozeCount: usedSnoozeCount,
                onStart: onStart,
                onSnooze: onSnooze,
                onCancel: onCancel,
                onQuit: onQuit
            )
            let window = FullscreenWindowFactory.make(screen: screen, title: "puz", rootView: view)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}

struct PromptView: View {
    let routine: Routine
    let scheduledDate: Date
    let usedSnoozeCount: Int
    let onStart: () -> Void
    let onSnooze: (SnoozeDelayOption) -> Void
    let onCancel: () -> Void
    let onQuit: () -> Void

    private var snoozeState: SnoozePromptState {
        SnoozePromptState(policy: routine.snoozePolicy, usedCount: usedSnoozeCount)
    }

    private var minutesText: String {
        let minutes = max(1, routine.countdownSeconds / 60)
        return "\(minutes)분"
    }

    private var scheduledText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledDate)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            PuzEntranceFlash()

            Button("×") { onCancel() }
                .buttonStyle(
                    PuzBigButtonStyle(
                        accent: .white,
                        foreground: .white,
                        filledForeground: .white,
                        hoverFill: .white.opacity(0.12),
                        minWidth: 38,
                        minHeight: 38,
                        fontSize: 20,
                        horizontalPadding: 0,
                        cornerRadius: 19,
                        lineWidth: 1.25
                    )
                )
                .focusable(false)
                .accessibilityLabel("전체 화면 닫기")
                .padding(.top, 34)
                .padding(.trailing, 38)

            VStack(spacing: 34) {
                Text("<//> puz")
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.52))

                VStack(spacing: 16) {
                    Text("\(routine.title) 할 시간이에요")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.45)

                    Text("\(scheduledText) 알림 · \(minutesText) 카운트다운")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                }

                VStack(spacing: 20) {
                    Button("지금 시작") { onStart() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(PuzBigButtonStyle(accent: .white, filledForeground: .black, minWidth: 380, minHeight: 98, fontSize: 40, lineWidth: 2.5))

                    Text("하던 게 있으면 잠깐 마무리하고 돌아오세요")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))

                    VStack(spacing: 14) {
                        Text(snoozeState.remainingText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(snoozeState.canSnooze ? .white.opacity(0.78) : .white.opacity(0.42))

                        ViewThatFits {
                            HStack(spacing: 18) { snoozeButtons }
                            VStack(spacing: 16) { snoozeButtons }
                        }
                    }
                }

                Button("앱 종료") { onQuit() }
                    .buttonStyle(
                        PuzBigButtonStyle(
                            accent: .white.opacity(0.46),
                            foreground: .white.opacity(0.62),
                            filledForeground: .white.opacity(0.9),
                            hoverFill: .white.opacity(0.12),
                            minWidth: 170,
                            minHeight: 54,
                            fontSize: 20,
                            lineWidth: 1.5
                        )
                    )
            }
            .padding(48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var snoozeButtons: some View {
        ForEach(SnoozeDelayOption.promptOptions, id: \.self) { option in
            Button(option.buttonTitle) { onSnooze(option) }
                .disabled(!snoozeState.canSnooze)
                .buttonStyle(
                    PuzBigButtonStyle(
                        accent: accent(for: option),
                        foreground: accent(for: option),
                        filledForeground: .black,
                        minWidth: 210,
                        minHeight: 82,
                        fontSize: 30
                    )
                )
        }
    }

    private func accent(for option: SnoozeDelayOption) -> Color {
        switch option {
        case .oneMinute:
            return Color(red: 1.0, green: 0.92, blue: 0.45)
        case .thirtyMinutes:
            return Color(red: 0.68, green: 0.86, blue: 1.0)
        case .random:
            return Color(red: 0.78, green: 1.0, blue: 0.70)
        }
    }
}
