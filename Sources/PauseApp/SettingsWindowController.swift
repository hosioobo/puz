import AppKit
import SwiftUI
import PauseCore

final class SettingsWindowController {
    var onSave: (() -> Void)?

    private let store: RoutineStore
    private let strings = PuzLocalization.current
    private var window: NSWindow?

    init(store: RoutineStore) {
        self.store = store
    }

    func show(afterSave: (() -> Void)? = nil) {
        let routines = store.routines
        let view = RoutinesSettingsView(
            routines: routines,
            onSave: { [weak self] updated in
                self?.store.replaceRoutines(updated)
                self?.onSave?()
                afterSave?()
                self?.window?.orderOut(nil)
            },
            onCancel: { [weak self] in
                self?.window?.orderOut(nil)
            }
        )

        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 660),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window?.title = strings.settingsTitle
            window?.isReleasedWhenClosed = false
            window?.center()
        }
        window?.title = strings.settingsTitle
        window?.contentView = NSHostingView(rootView: view)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct RoutinesSettingsView: View {
    private let onSave: ([Routine]) -> Void
    private let onCancel: () -> Void
    private let strings = PuzLocalization.current

    @State private var routines: [Routine]
    @State private var savedSnapshot: [Routine]
    @State private var selectedID: UUID?

    init(routines: [Routine], onSave: @escaping ([Routine]) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        _routines = State(initialValue: routines)
        _savedSnapshot = State(initialValue: routines)
        _selectedID = State(initialValue: routines.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 250)
                Divider()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            footer
        }
        .frame(width: 880, height: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: routines) { _ in
            repairSelection()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(strings.routinesTitle)
                    .font(.title3.bold())
                Spacer()
                Text("\(routines.count)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            if routines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.noRoutinesMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(routines) { routine in
                            routineRow(routine)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }

            Divider()
            HStack(spacing: 8) {
                Button(strings.newRoutineLabel) {
                    addRoutine()
                }
                .keyboardShortcut("n")

                Button(strings.duplicateRoutineLabel) {
                    duplicateSelectedRoutine()
                }
                .disabled(selectedID == nil)

                Button(strings.deleteRoutineLabel) {
                    deleteSelectedRoutine()
                }
                .disabled(selectedID == nil)
            }
            .font(.footnote)
            .padding([.horizontal, .bottom], 12)
        }
    }

    private var detail: some View {
        Group {
            if let index = selectedIndex {
                ScrollView {
                    RoutineEditorView(routine: $routines[index], strings: strings)
                        .padding(24)
                }
            } else {
                emptyRoutineDetail
            }
        }
    }

    private var emptyRoutineDetail: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(PuzFullscreenTheme.accent)
            Text(strings.noRoutinesTitle)
                .font(.title3.bold())
            Text(strings.noRoutinesMessage)
                .foregroundStyle(.secondary)
            Button(strings.newRoutineLabel) {
                addRoutine()
            }
            .buttonStyle(.borderedProminent)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if isDirty {
                Text(strings.unsavedChangesLabel)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Spacer(minLength: 0)
            }

            Spacer()

            Button(strings.cancelLabel) {
                routines = savedSnapshot
                selectedID = savedSnapshot.first?.id
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button(strings.saveLabel) {
                let prepared = preparedRoutines()
                savedSnapshot = prepared
                routines = prepared
                onSave(prepared)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(isDirty ? Color.red : Color.accentColor)
            .disabled(!isDirty || validationMessage != nil)
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func routineRow(_ routine: Routine) -> some View {
        let isSelected = routine.id == selectedID
        let title = displayTitle(for: routine)
        let firstWindow = routine.windows.sortedByStart.first
        return Button {
            selectedID = routine.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(routine.isEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                }
                HStack(spacing: 6) {
                    Text(strings.routineRunsSummary(runsPerDay: routine.frequency.runsPerDay))
                    if let firstWindow {
                        Text("·")
                        Text(strings.routineWindowSummary(start: firstWindow.start, end: firstWindow.end))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return routines.firstIndex(where: { $0.id == selectedID })
    }

    private var isDirty: Bool {
        preparedRoutines() != savedSnapshot
    }

    private var validationMessage: String? {
        for routine in routines {
            if let message = validationMessage(for: routine) {
                return message
            }
        }
        return nil
    }

    private func addRoutine() {
        let window = RoutineWindow(
            label: strings.windowsLabel,
            start: DailyTime(hour: 9, minute: 0),
            end: DailyTime(hour: 18, minute: 0)
        )
        let routine = Routine(
            title: strings.newRoutineDefaultTitle,
            actionType: .stretch,
            schedule: .randomWindow(start: window.start, end: window.end),
            countdownSeconds: 5 * 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            isEnabled: true,
            activeWeekdays: Set(Weekday.allCases),
            windows: [window],
            frequency: RoutineFrequency(runsPerDay: 1, minimumGapMinutes: 60, distribution: .evenlySpread)
        )
        routines.append(routine)
        selectedID = routine.id
    }

    private func duplicateSelectedRoutine() {
        guard let index = selectedIndex else { return }
        let original = routines[index]
        let duplicate = Routine(
            title: strings.copiedRoutineTitle(displayTitle(for: original)),
            actionType: original.actionType,
            schedule: original.schedule,
            countdownSeconds: original.countdownSeconds,
            snoozePolicy: original.snoozePolicy,
            isEnabled: original.isEnabled,
            activeWeekdays: original.activeWeekdays,
            windows: original.windows.map { RoutineWindow(label: $0.label, start: $0.start, end: $0.end) },
            frequency: original.frequency,
            exactDailyTimes: original.exactDailyTimes,
            glyphSymbolName: original.glyphSymbolName
        )
        routines.insert(duplicate, at: index + 1)
        selectedID = duplicate.id
    }

    private func deleteSelectedRoutine() {
        guard let index = selectedIndex else { return }
        routines.remove(at: index)
        if routines.indices.contains(index) {
            selectedID = routines[index].id
        } else {
            selectedID = routines.last?.id
        }
    }

    private func repairSelection() {
        if let selectedID, routines.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = routines.first?.id
    }

    private func preparedRoutines() -> [Routine] {
        routines.map(normalizedRoutine)
    }

    private func normalizedRoutine(_ routine: Routine) -> Routine {
        RoutineSettingsNormalizer.normalized(routine)
    }

    private func validationMessage(for routine: Routine) -> String? {
        let title = displayTitle(for: routine)
        switch RoutineValidator.validationIssue(for: routine) {
        case .noWeekdays:
            return strings.validationNoWeekdays(routineTitle: title)
        case .noWindows:
            return strings.validationNoWindows(routineTitle: title)
        case .invalidWindow:
            return strings.validationInvalidWindow(routineTitle: title)
        case .overlappingWindows:
            return strings.validationOverlappingWindows(routineTitle: title)
        case .impossibleFrequency:
            return strings.validationImpossibleFrequency(routineTitle: title)
        case nil:
            return nil
        }
    }

    private func displayTitle(for routine: Routine) -> String {
        let trimmed = routine.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? strings.actionName(routine.actionType) : trimmed
    }
}

struct RoutineEditorView: View {
    @Binding var routine: Routine
    let strings: PuzLocalization
    private let glyphChoices = OnboardingGlyphChoice.defaults
    @State private var isAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(strings.routineTitle(routine))
                .font(.largeTitle.bold())
                .lineLimit(1)

            settingsSection(strings.basicsSectionTitle) {
                Toggle(strings.enabledLabel, isOn: $routine.isEnabled)

                TextField(strings.routineNamePlaceholder, text: $routine.title)
                    .textFieldStyle(.roundedBorder)

                Picker(strings.glyphLabel, selection: glyphSymbolBinding) {
                    ForEach(glyphChoices, id: \.symbolName) { choice in
                        Label(choice.title, systemImage: choice.symbolName).tag(choice.symbolName)
                    }
                }
                .pickerStyle(.menu)

                Stepper(value: bounded($routine.countdownSeconds, range: 60...(120 * 60), step: 60), in: 60...(120 * 60), step: 60) {
                    HStack(spacing: 8) {
                        Text(strings.countdownLabel)
                        NumericTimeField(value: countdownMinutesBinding, range: 1...120, width: 54, padded: false)
                        Text(strings.minuteUnit)
                    }
                }

                Stepper(value: bounded($routine.snoozePolicy.maxCount, range: 0...9), in: 0...9) {
                    HStack(spacing: 8) {
                        Text(strings.maxSnoozeLabel)
                        NumericTimeField(value: $routine.snoozePolicy.maxCount, range: 0...9, width: 42, padded: false)
                        Text(strings.countUnit)
                    }
                }
            }

            DisclosureGroup(isExpanded: $isAdvanced) {
                VStack(alignment: .leading, spacing: 16) {
                    settingsSection(strings.whenSectionTitle) {
                        Text(strings.weekdaysLabel)
                            .font(.subheadline.bold())
                        weekdayChips

                        HStack {
                            Text(strings.windowsLabel)
                                .font(.subheadline.bold())
                            Spacer()
                            Button(strings.addWindowLabel) {
                                addWindow()
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach($routine.windows) { $window in
                                windowEditor(window: $window)
                            }
                        }
                    }

                    settingsSection(strings.howOftenSectionTitle) {
                        Stepper(value: bounded($routine.frequency.runsPerDay, range: 1...12), in: 1...12) {
                            HStack(spacing: 8) {
                                Text(strings.runsPerDayLabel)
                                NumericTimeField(value: $routine.frequency.runsPerDay, range: 1...12, width: 44, padded: false)
                                Text(strings.countUnit)
                            }
                        }

                        Stepper(value: bounded($routine.frequency.minimumGapMinutes, range: 0...360), in: 0...360, step: 5) {
                            HStack(spacing: 8) {
                                Text(strings.minimumGapLabel)
                                NumericTimeField(value: $routine.frequency.minimumGapMinutes, range: 0...360, width: 54, padded: false)
                                Text(strings.minuteUnit)
                            }
                        }

                        Picker(strings.distributionLabel, selection: $routine.frequency.distribution) {
                            ForEach(DistributionMode.allCases, id: \.self) { mode in
                                Text(strings.distributionName(mode)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } label: {
                Text(strings.advancedSettingsTitle)
                    .font(.headline)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekdayChips: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                let isActive = routine.activeWeekdays.contains(weekday)
                Button {
                    toggleWeekday(weekday)
                } label: {
                    Text(strings.weekdayShortName(weekday))
                        .frame(minWidth: 30)
                }
                .buttonStyle(.bordered)
                .tint(isActive ? Color.accentColor : Color.gray)
            }
        }
    }

    private var glyphSymbolBinding: Binding<String> {
        Binding(
            get: { routine.glyphSymbolName ?? defaultGlyphSymbolName(for: routine.actionType) },
            set: { routine.glyphSymbolName = $0 }
        )
    }

    private var countdownMinutesBinding: Binding<Int> {
        Binding(
            get: { max(1, routine.countdownSeconds / 60) },
            set: { routine.countdownSeconds = TimeInputSanitizer.clampedValue(from: "\($0)", fallback: 10, range: 1...120) * 60 }
        )
    }

    private func defaultGlyphSymbolName(for actionType: ActionType) -> String {
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

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func windowEditor(window: Binding<RoutineWindow>) -> some View {
        HStack(spacing: 10) {
            TextField(strings.windowLabelPlaceholder, text: window.label)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)

            Text(strings.startLabel)
            TimeStepper(hour: window.start.hour, minute: window.start.minute)

            Text(strings.endLabel)
            TimeStepper(hour: window.end.hour, minute: window.end.minute)

            Spacer()

            Button(role: .destructive) {
                routine.windows.removeAll { $0.id == window.wrappedValue.id }
            } label: {
                Image(systemName: "trash")
            }
            .help(strings.deleteWindowLabel)
            .disabled(routine.windows.count <= 1)
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func toggleWeekday(_ weekday: Weekday) {
        if routine.activeWeekdays.contains(weekday) {
            routine.activeWeekdays.remove(weekday)
        } else {
            routine.activeWeekdays.insert(weekday)
        }
    }

    private func addWindow() {
        routine.windows.append(
            RoutineWindow(
                label: strings.windowsLabel,
                start: DailyTime(hour: 9, minute: 0),
                end: DailyTime(hour: 18, minute: 0)
            )
        )
    }

    private func bounded(_ binding: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> Binding<Int> {
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

private extension DailyTime {
    var totalMinutes: Int {
        hour * 60 + minute
    }
}

private extension Array where Element == RoutineWindow {
    var sortedByStart: [RoutineWindow] {
        sorted {
            if $0.start.totalMinutes == $1.start.totalMinutes {
                return $0.end.totalMinutes < $1.end.totalMinutes
            }
            return $0.start.totalMinutes < $1.start.totalMinutes
        }
    }

    var hasOverlaps: Bool {
        let sorted = sortedByStart
        return zip(sorted, sorted.dropFirst()).contains { previous, next in
            next.start.totalMinutes < previous.end.totalMinutes
        }
    }
}
