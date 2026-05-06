import AppKit
import SwiftUI
import PauseCore

final class SettingsWindowController {
    var onSave: (() -> Void)?

    private let store: RoutineStore
    private var window: NSWindow?

    init(store: RoutineStore) {
        self.store = store
    }

    func show(afterSave: (() -> Void)? = nil) {
        let routine = store.routines.first ?? Routine.defaultBurpee()
        let view = RoutineSettingsView(routine: routine) { [weak self] updated in
            self?.store.saveRoutines([updated])
            self?.onSave?()
            afterSave?()
            self?.window?.orderOut(nil)
        }

        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 590),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "puz 설정"
            window?.isReleasedWhenClosed = false
            window?.center()
        }
        window?.contentView = NSHostingView(rootView: view)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct RoutineSettingsView: View {
    private let routineID: UUID
    private let compatibilitySnoozePolicy: SnoozePolicy
    private let onSave: (Routine) -> Void

    @State private var title: String
    @State private var actionType: ActionType
    @State private var isEnabled: Bool
    @State private var usesRandomWindow: Bool
    @State private var fixedHour: Int
    @State private var fixedMinute: Int
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var countdownMinutes: Int
    @State private var maxSnoozeCount: Int

    init(routine: Routine, onSave: @escaping (Routine) -> Void) {
        self.routineID = routine.id
        self.compatibilitySnoozePolicy = routine.snoozePolicy
        self.onSave = onSave
        _title = State(initialValue: routine.title)
        _actionType = State(initialValue: routine.actionType)
        _isEnabled = State(initialValue: routine.isEnabled)
        _countdownMinutes = State(initialValue: max(1, routine.countdownSeconds / 60))
        _maxSnoozeCount = State(initialValue: routine.snoozePolicy.maxCount)

        switch routine.schedule {
        case .fixedTime(let time):
            _usesRandomWindow = State(initialValue: false)
            _fixedHour = State(initialValue: time.hour)
            _fixedMinute = State(initialValue: time.minute)
            _startHour = State(initialValue: 9)
            _startMinute = State(initialValue: 0)
            _endHour = State(initialValue: 18)
            _endMinute = State(initialValue: 0)
        case .randomWindow(let start, let end):
            _usesRandomWindow = State(initialValue: true)
            _fixedHour = State(initialValue: start.hour)
            _fixedMinute = State(initialValue: start.minute)
            _startHour = State(initialValue: start.hour)
            _startMinute = State(initialValue: start.minute)
            _endHour = State(initialValue: end.hour)
            _endMinute = State(initialValue: end.minute)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("puz 설정")
                .font(.title.bold())

            Toggle("활성화", isOn: $isEnabled)

            TextField("루틴 이름", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("행동", selection: $actionType) {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            Picker("일정", selection: $usesRandomWindow) {
                Text("랜덤 구간").tag(true)
                Text("지정 시각").tag(false)
            }
            .pickerStyle(.segmented)

            if usesRandomWindow {
                HStack(spacing: 14) {
                    Text("시작")
                    TimeStepper(hour: $startHour, minute: $startMinute)
                    Text("종료")
                    TimeStepper(hour: $endHour, minute: $endMinute)
                }
            } else {
                HStack(spacing: 14) {
                    Text("시각")
                    TimeStepper(hour: $fixedHour, minute: $fixedMinute)
                }
            }

            Stepper(value: bounded($countdownMinutes, range: 1...120), in: 1...120) {
                HStack(spacing: 8) {
                    Text("카운트다운")
                    NumericTimeField(value: $countdownMinutes, range: 1...120, width: 54, padded: false)
                    Text("분")
                    Text("클릭해서 직접 입력 가능")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: bounded($maxSnoozeCount, range: 0...9), in: 0...9) {
                HStack(spacing: 8) {
                    Text("미루기 최대")
                    NumericTimeField(value: $maxSnoozeCount, range: 0...9, width: 42, padded: false)
                    Text("회")
                    Text("시작 화면에 남은 횟수로 표시")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text("시간은 스테퍼로 빠르게 조정하고, 숫자 칸을 클릭하면 정확히 입력할 수 있어요.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("미루기는 시작 화면에서 1분 후 / 30분 후 / 랜덤 버튼으로 고릅니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()
                Button("저장") {
                    onSave(makeRoutine())
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 580, height: 590)
    }

    private func makeRoutine() -> Routine {
        let schedule: Schedule = usesRandomWindow
            ? .randomWindow(start: DailyTime(hour: startHour, minute: startMinute), end: DailyTime(hour: endHour, minute: endMinute))
            : .fixedTime(DailyTime(hour: fixedHour, minute: fixedMinute))
        return Routine(
            id: routineID,
            title: title,
            actionType: actionType,
            schedule: schedule,
            countdownSeconds: TimeInputSanitizer.clampedValue(from: "\(countdownMinutes)", fallback: 10, range: 1...120) * 60,
            snoozePolicy: SnoozePolicy(
                maxCount: TimeInputSanitizer.clampedValue(from: "\(maxSnoozeCount)", fallback: compatibilitySnoozePolicy.maxCount, range: 0...9),
                intervalMinutes: compatibilitySnoozePolicy.intervalMinutes
            ),
            isEnabled: isEnabled
        )
    }

    private func bounded(_ binding: Binding<Int>, range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}

struct TimeStepper: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 6) {
            Stepper(value: $hour, in: 0...23) {
                NumericTimeField(value: $hour, range: 0...23, width: 38)
            }
            Text(":")
                .font(.system(.body, design: .monospaced).bold())
            Stepper(value: $minute, in: 0...59, step: 5) {
                NumericTimeField(value: $minute, range: 0...59, width: 38)
            }
        }
    }
}

struct NumericTimeField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat
    var padded: Bool = true

    @FocusState private var isFocused: Bool
    @State private var draft = ""

    var body: some View {
        TextField("", text: Binding(
            get: {
                isFocused ? draft : formatted(value)
            },
            set: { newValue in
                let digits = TimeInputSanitizer.digitsOnly(newValue)
                draft = digits
                value = TimeInputSanitizer.clampedValue(from: digits, fallback: value, range: range)
            }
        ))
        .font(.system(.body, design: .monospaced))
        .multilineTextAlignment(.center)
        .textFieldStyle(.roundedBorder)
        .frame(width: width)
        .focused($isFocused)
        .onAppear {
            draft = formatted(value)
        }
        .onSubmit {
            commitDraft()
        }
        .onChange(of: isFocused) { focused in
            if focused {
                draft = formatted(value)
            } else {
                commitDraft()
            }
        }
        .onChange(of: value) { newValue in
            if !isFocused {
                draft = formatted(newValue)
            }
        }
    }

    private func commitDraft() {
        value = TimeInputSanitizer.clampedValue(from: draft, fallback: value, range: range)
        draft = formatted(value)
    }

    private func formatted(_ value: Int) -> String {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return padded ? String(format: "%02d", clamped) : "\(clamped)"
    }
}
