import AppKit
import SwiftUI
import Combine
import PauseCore

final class OverlayController {
    private var windows: [NSWindow] = []
    private var session: CountdownSession?

    func startCountdown(
        routine: Routine,
        onComplete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        closeWindows()

        let session = CountdownSession(
            totalSeconds: routine.countdownSeconds,
            onResume: { [weak self] in
                self?.closeWindows()
                onComplete()
            },
            onCancel: { [weak self] in
                self?.closeWindows()
                onCancel()
            }
        )
        self.session = session

        for screen in NSScreen.screens {
            let view = CountdownOverlayView(
                routine: routine,
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
    private let onCancel: () -> Void

    init(totalSeconds: Int, onResume: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.totalSeconds = max(1, totalSeconds)
        self.remainingSeconds = max(1, totalSeconds)
        self.onResume = onResume
        self.onCancel = onCancel
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

    func cancel() {
        guard !didExit else { return }
        didExit = true
        stop()
        onCancel()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct CountdownOverlayView: View {
    let routine: Routine
    @ObservedObject var session: CountdownSession

    private var remainingText: String {
        let minutes = session.remainingSeconds / 60
        let seconds = session.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            PuzEntranceFlash()

            Button("×") { session.cancel() }
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
                .accessibilityLabel("카운트다운 취소")
                .padding(.top, 34)
                .padding(.trailing, 38)

            VStack(spacing: 34) {
                Text("<//> puz")
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                Text(session.isComplete ? "끝났어요" : routine.title)
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                TimerProgressRingView(text: remainingText, progress: session.progress)

                if session.isComplete {
                    Text("준비되면 Resume을 눌러 화면을 다시 열어요")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))

                    Button("Resume") { session.resume() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(PuzBigButtonStyle(accent: .white, filledForeground: .black, minWidth: 360, minHeight: 104, fontSize: 44, lineWidth: 2.5))
                } else {
                    Text("끝날 때까지 진행 · 완료 후 Resume으로 복귀")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TimerProgressRingView: View {
    let text: String
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 6)

            Circle()
                .trim(from: 1 - progress, to: 1)
                .stroke(
                    .white,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)

            Text(text)
                .font(.system(size: 108, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
        }
        .frame(width: 380, height: 380)
        .padding(8)
    }
}
