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
        onEndSession: @escaping (SessionEndAction) -> Void,
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
                onEndSession: onEndSession,
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
    let onEndSession: (SessionEndAction) -> Void
    let onQuit: () -> Void

    @State private var showsEndSessionDialog = false

    private let strings = PuzLocalization.current

    private var snoozeState: SnoozePromptState {
        SnoozePromptState(policy: routine.snoozePolicy, usedCount: usedSnoozeCount)
    }

    private var minutesValue: Int {
        max(1, (routine.countdownSeconds + 59) / 60)
    }

    private var minutesText: String {
        strings.minuteCount(minutesValue)
    }

    var body: some View {
        ZStack {
            PuzFullscreenBackground()
            PuzEntranceFlash()

            VStack(spacing: 24) {
                Spacer(minLength: 92)

                PuzRoutineGlyph(actionType: routine.actionType)
                    .padding(.bottom, 4)

                VStack(spacing: 14) {
                    Text(strings.promptHeadline(for: routine))
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.text)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.45)

                    Text(strings.promptActionDescription(actionType: routine.actionType, minutes: minutesValue))
                        .font(.system(size: 25, weight: .medium, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                }

                Text(strings.snoozeRemainingText(count: snoozeState.remainingCount))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(snoozeState.canSnooze ? PuzFullscreenTheme.secondaryText : PuzFullscreenTheme.mutedText)
                    .padding(.top, 18)

                VStack(spacing: 28) {
                    Button(strings.startSessionButtonTitle(duration: minutesText)) { onStart() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(
                            PuzBigButtonStyle(
                                accent: PuzFullscreenTheme.accent,
                                foreground: PuzFullscreenTheme.accent,
                                filledForeground: .white,
                                hoverFill: PuzFullscreenTheme.accent,
                                minWidth: 720,
                                minHeight: 94,
                                fontSize: 39,
                                cornerRadius: 28,
                                lineWidth: 2
                            )
                        )

                    ViewThatFits {
                        HStack(spacing: 22) { snoozeButtons }
                        VStack(spacing: 16) { snoozeButtons }
                    }
                }

                PuzInfoLine(text: strings.promptHelper)
                    .padding(.top, 16)

                Spacer(minLength: 82)
            }
            .padding(.horizontal, 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topLeading) {
            PuzBrandLockup()
                .padding(.top, 45)
                .padding(.leading, 50)
        }
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.top, 36)
                .padding(.trailing, 42)
        }
        .overlay {
            if showsEndSessionDialog {
                PuzEndSessionDialog(
                    canSnooze: snoozeState.canSnooze,
                    onAction: { action in
                        showsEndSessionDialog = false
                        onEndSession(action)
                    },
                    onKeepGoing: {
                        showsEndSessionDialog = false
                    }
                )
            }
        }
        .animation(.easeOut(duration: 0.16), value: showsEndSessionDialog)
    }

    private var closeButton: some View {
        Button("×") { showsEndSessionDialog = true }
            .buttonStyle(
                PuzBigButtonStyle(
                    accent: PuzFullscreenTheme.hairline,
                    foreground: PuzFullscreenTheme.secondaryText,
                    filledForeground: PuzFullscreenTheme.text,
                    hoverFill: PuzFullscreenTheme.hairline.opacity(0.18),
                    minWidth: 42,
                    minHeight: 42,
                    fontSize: 22,
                    horizontalPadding: 0,
                    cornerRadius: 21,
                    lineWidth: 1.25
                )
            )
            .focusable(false)
            .accessibilityLabel(strings.fullscreenCloseAccessibilityLabel)
    }

    @ViewBuilder
    private var snoozeButtons: some View {
        ForEach(SnoozeDelayOption.promptOptions, id: \.self) { option in
            Button { onSnooze(option) } label: {
                VStack(spacing: 4) {
                    Text(strings.snoozeButtonTitle(option))
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                    if let subtitle = strings.snoozeButtonSubtitle(option) {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(snoozeState.canSnooze ? PuzFullscreenTheme.secondaryText : PuzFullscreenTheme.mutedText)
                    }
                }
            }
            .disabled(!snoozeState.canSnooze)
            .buttonStyle(
                PuzBigButtonStyle(
                    accent: PuzFullscreenTheme.accent,
                    foreground: PuzFullscreenTheme.accent,
                    filledForeground: .white,
                    hoverFill: PuzFullscreenTheme.accent,
                    minWidth: 220,
                    minHeight: 82,
                    fontSize: 23,
                    cornerRadius: 16,
                    lineWidth: 1.5
                )
            )
        }
    }
}
