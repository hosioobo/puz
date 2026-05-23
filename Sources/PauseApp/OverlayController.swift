import AppKit
import SwiftUI
import Combine
import PauseCore

final class OverlayController {
    private var windows: [NSWindow] = []
    private var session: CountdownSession?

    func startCountdown(
        routine: Routine,
        usedSnoozeCount: Int,
        onComplete: @escaping () -> Void,
        onEndSession: @escaping (SessionEndAction) -> Void
    ) {
        closeWindows()

        let session = CountdownSession(
            totalSeconds: routine.countdownSeconds,
            onResume: { [weak self] in
                self?.closeWindows()
                onComplete()
            },
            onEndSession: { [weak self] action in
                self?.closeWindows()
                onEndSession(action)
            }
        )
        self.session = session

        for screen in NSScreen.screens {
            let view = CountdownOverlayView(
                routine: routine,
                usedSnoozeCount: usedSnoozeCount,
                session: session
            )
            let window = FullscreenWindowFactory.make(screen: screen, title: "puz", rootView: view)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        session.start()
    }

    private func closeWindows() {
        session?.stop()
        session = nil
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}

final class CountdownSession: ObservableObject {
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var isComplete = false

    let totalSeconds: Int

    private var timer: Timer?
    private var didExit = false
    private let onResume: () -> Void
    private let onEndSession: (SessionEndAction) -> Void

    init(totalSeconds: Int, onResume: @escaping () -> Void, onEndSession: @escaping (SessionEndAction) -> Void) {
        self.totalSeconds = max(1, totalSeconds)
        self.remainingSeconds = max(1, totalSeconds)
        self.onResume = onResume
        self.onEndSession = onEndSession
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, Double(remainingSeconds) / Double(totalSeconds)))
    }

    func start() {
        stop()
        didExit = false
        isComplete = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            if self.remainingSeconds <= 1 {
                self.remainingSeconds = 0
                self.isComplete = true
                timer.invalidate()
                self.timer = nil
            } else {
                self.remainingSeconds -= 1
            }
        }
    }

    func resume() {
        guard isComplete, !didExit else { return }
        didExit = true
        stop()
        onResume()
    }

    func endSession(_ action: SessionEndAction) {
        guard !didExit else { return }
        didExit = true
        stop()
        onEndSession(action)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct CountdownOverlayView: View {
    let routine: Routine
    let usedSnoozeCount: Int
    @ObservedObject var session: CountdownSession

    @State private var showsEndSessionDialog = false

    private let strings = PuzLocalization.current

    private var minutesValue: Int {
        max(1, (routine.countdownSeconds + 59) / 60)
    }

    private var remainingText: String {
        let minutes = session.remainingSeconds / 60
        let seconds = session.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var localizedRoutineTitle: String {
        strings.routineTitle(routine)
    }

    private var titleText: String {
        session.isComplete ? strings.countdownCompleteTitle : strings.activeSessionTitle(for: routine.actionType)
    }

    private var subtitleText: String {
        if session.isComplete {
            return strings.completionSubtitle(routineTitle: localizedRoutineTitle, minutes: minutesValue)
        }
        return strings.focusText(for: routine.actionType)
    }

    private var ringProgress: Double {
        session.isComplete ? 1 : session.progress
    }

    private var canSnoozeFromDialog: Bool {
        SnoozePromptState(policy: routine.snoozePolicy, usedCount: usedSnoozeCount).canSnooze
    }

    var body: some View {
        ZStack {
            PuzFullscreenBackground()
            PuzEntranceFlash()

            VStack(spacing: 16) {
                Spacer(minLength: 86)

                PuzRoutineGlyph(actionType: routine.actionType, symbolName: routine.glyphSymbolName, isComplete: session.isComplete)
                    .padding(.bottom, 4)

                VStack(spacing: 10) {
                    Text(titleText)
                        .font(.system(size: session.isComplete ? 72 : 58, weight: .heavy, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.text)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.45)

                    Text(subtitleText)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                }

                TimerProgressRingView(text: remainingText, progress: ringProgress, isComplete: session.isComplete)
                    .padding(.top, 14)

                if session.isComplete {
                    Button(strings.resumeButtonTitle) { session.resume() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(
                            PuzBigButtonStyle(
                                accent: PuzFullscreenTheme.accent,
                                foreground: PuzFullscreenTheme.accent,
                                filledForeground: .white,
                                hoverFill: PuzFullscreenTheme.accent,
                                minWidth: 480,
                                minHeight: 90,
                                fontSize: 36,
                                cornerRadius: 18,
                                lineWidth: 1.5,
                                isKeyboardFocused: session.isComplete && !showsEndSessionDialog
                            )
                        )
                        .padding(.top, 10)

                    Text(strings.resumeInstruction)
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.secondaryText)
                        .padding(.top, 10)
                } else {
                    Text(strings.sessionProgressText(minutes: minutesValue))
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.secondaryText)
                        .padding(.top, 6)

                    PuzSessionStepsRow(
                        labels: strings.sessionStepLabels(for: routine.actionType),
                        symbols: stepSymbols(for: routine.actionType)
                    )
                    .padding(.top, 8)

                    PuzInfoLine(text: strings.countdownProgressInstruction)
                        .padding(.top, 18)
                }

                Spacer(minLength: 80)
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
                    canSnooze: canSnoozeFromDialog,
                    onAction: { action in
                        showsEndSessionDialog = false
                        session.endSession(action)
                    },
                    onKeepGoing: {
                        showsEndSessionDialog = false
                    }
                )
            }
        }
        .puzKeyboardShortcuts { handleKeyboardCommand($0) }
        .animation(.easeOut(duration: 0.16), value: showsEndSessionDialog)
    }

    private func handleKeyboardCommand(_ command: PuzKeyboardCommand) -> Bool {
        guard !showsEndSessionDialog else { return false }
        switch command {
        case .confirm where session.isComplete:
            session.resume()
            return true
        case .moveNext, .movePrevious:
            return session.isComplete
        default:
            return false
        }
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
            .accessibilityLabel(strings.countdownCancelAccessibilityLabel)
    }

    private func stepSymbols(for actionType: ActionType) -> [String] {
        switch actionType {
        case .burpee:
            return ["figure.walk", "timer", "wind"]
        case .standUp:
            return ["figure.stand", "arrow.triangle.2.circlepath", "eye"]
        case .drinkWater:
            return ["drop", "wind", "sparkles"]
        case .stretch:
            return ["arrow.triangle.2.circlepath", "person.crop.circle", "figure.walk"]
        case .eyeRest:
            return ["eye", "arrow.up.left.and.arrow.down.right", "sparkles"]
        case .exercise:
            return ["figure.walk", "checkmark.seal", "wind"]
        }
    }
}

struct TimerProgressRingView: View {
    let text: String
    let progress: Double
    var isComplete = false

    private var clampedProgress: Double {
        max(0, min(1, progress))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(PuzFullscreenTheme.ringTrack, lineWidth: 4)

            Circle()
                .trim(from: 1 - clampedProgress, to: 1)
                .stroke(
                    PuzFullscreenTheme.accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: clampedProgress)

            Text(text)
                .font(.system(size: 82, weight: .heavy, design: .monospaced))
                .foregroundStyle(isComplete ? PuzFullscreenTheme.accent : PuzFullscreenTheme.text)
                .minimumScaleFactor(0.45)
        }
        .frame(width: 316, height: 316)
        .padding(8)
    }
}

struct PuzSessionStepsRow: View {
    let labels: [String]
    let symbols: [String]

    var body: some View {
        HStack(spacing: 26) {
            ForEach(labels.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    Image(systemName: index < symbols.count ? symbols[index] : "circle")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(PuzFullscreenTheme.accent)
                        .symbolRenderingMode(.hierarchical)
                    Text(labels[index])
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(PuzFullscreenTheme.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(minWidth: 122)

                if index < labels.count - 1 {
                    Rectangle()
                        .fill(PuzFullscreenTheme.hairline)
                        .frame(width: 1, height: 52)
                }
            }
        }
    }
}
