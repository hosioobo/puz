import Foundation

public enum RecommendedPuzTemplateKey: String, Codable, CaseIterable, Equatable, Hashable {
    case hydrate
    case stretch
    case eyeRest
}

public struct RecommendedPuzTemplate: Equatable, Hashable {
    public let key: RecommendedPuzTemplateKey
    public let title: String
    public let actionType: ActionType
    public let countdownSeconds: Int
    public let dailyTimes: [DailyTime]
    public let snoozePolicy: SnoozePolicy
    public let isPreselected: Bool

    public init(
        key: RecommendedPuzTemplateKey,
        title: String,
        actionType: ActionType,
        countdownSeconds: Int,
        dailyTimes: [DailyTime],
        snoozePolicy: SnoozePolicy = SnoozePolicy(maxCount: 2, intervalMinutes: 30),
        isPreselected: Bool
    ) {
        self.key = key
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.actionType = actionType
        self.countdownSeconds = max(1, countdownSeconds)
        self.dailyTimes = dailyTimes
        self.snoozePolicy = snoozePolicy
        self.isPreselected = isPreselected
    }

    public static let defaults: [RecommendedPuzTemplate] = [
        RecommendedPuzTemplate(
            key: .hydrate,
            title: "Hydrate",
            actionType: .drinkWater,
            countdownSeconds: 20,
            dailyTimes: [
                DailyTime(hour: 10, minute: 30),
                DailyTime(hour: 13, minute: 30),
                DailyTime(hour: 16, minute: 30)
            ],
            isPreselected: false
        ),
        RecommendedPuzTemplate(
            key: .stretch,
            title: "Stretch",
            actionType: .stretch,
            countdownSeconds: 90,
            dailyTimes: [
                DailyTime(hour: 11, minute: 0),
                DailyTime(hour: 15, minute: 30)
            ],
            isPreselected: true
        ),
        RecommendedPuzTemplate(
            key: .eyeRest,
            title: "Eye rest",
            actionType: .eyeRest,
            countdownSeconds: 20,
            dailyTimes: [
                DailyTime(hour: 10, minute: 45),
                DailyTime(hour: 14, minute: 15),
                DailyTime(hour: 17, minute: 0)
            ],
            isPreselected: false
        )
    ]
}

public struct CustomRoutineDraft: Equatable, Hashable, Codable {
    public var name: String
    public var glyphSymbolName: String?
    public var dailyTime: DailyTime
    public var dailyCount: Int

    public init(name: String, glyphSymbolName: String?, dailyTime: DailyTime, dailyCount: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGlyph = glyphSymbolName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmedName
        self.glyphSymbolName = trimmedGlyph?.isEmpty == true ? nil : trimmedGlyph
        self.dailyTime = dailyTime
        self.dailyCount = min(max(dailyCount, 1), 12)
    }
}

public struct OnboardingGlyphChoice: Equatable, Hashable, Codable {
    public let symbolName: String
    public let title: String

    public init(symbolName: String, title: String) {
        self.symbolName = symbolName
        self.title = title
    }

    public static let defaults: [OnboardingGlyphChoice] = [
        OnboardingGlyphChoice(symbolName: "figure.walk", title: "Walk"),
        OnboardingGlyphChoice(symbolName: "figure.stand", title: "Stand"),
        OnboardingGlyphChoice(symbolName: "figure.run", title: "Run"),
        OnboardingGlyphChoice(symbolName: "drop", title: "Water"),
        OnboardingGlyphChoice(symbolName: "eye", title: "Eyes"),
        OnboardingGlyphChoice(symbolName: "sparkles", title: "Sparkles"),
        OnboardingGlyphChoice(symbolName: "leaf", title: "Leaf"),
        OnboardingGlyphChoice(symbolName: "flame", title: "Energy"),
        OnboardingGlyphChoice(symbolName: "heart", title: "Heart"),
        OnboardingGlyphChoice(symbolName: "bolt", title: "Bolt"),
        OnboardingGlyphChoice(symbolName: "moon", title: "Rest"),
        OnboardingGlyphChoice(symbolName: "sun.max", title: "Sun"),
        OnboardingGlyphChoice(symbolName: "wind", title: "Breath"),
        OnboardingGlyphChoice(symbolName: "timer", title: "Timer"),
        OnboardingGlyphChoice(symbolName: "clock", title: "Clock"),
        OnboardingGlyphChoice(symbolName: "calendar", title: "Calendar"),
        OnboardingGlyphChoice(symbolName: "checkmark.circle", title: "Check"),
        OnboardingGlyphChoice(symbolName: "star", title: "Star"),
        OnboardingGlyphChoice(symbolName: "flag", title: "Flag"),
        OnboardingGlyphChoice(symbolName: "target", title: "Target"),
        OnboardingGlyphChoice(symbolName: "house", title: "Home"),
        OnboardingGlyphChoice(symbolName: "book", title: "Read"),
        OnboardingGlyphChoice(symbolName: "pencil", title: "Write"),
        OnboardingGlyphChoice(symbolName: "paintbrush", title: "Create"),
        OnboardingGlyphChoice(symbolName: "music.note", title: "Music"),
        OnboardingGlyphChoice(symbolName: "camera", title: "Camera"),
        OnboardingGlyphChoice(symbolName: "headphones", title: "Listen"),
        OnboardingGlyphChoice(symbolName: "gamecontroller", title: "Play"),
        OnboardingGlyphChoice(symbolName: "phone.down", title: "Disconnect"),
        OnboardingGlyphChoice(symbolName: "bell", title: "Reminder")
    ]
}

public struct OnboardingSelection: Equatable, Hashable, Codable {
    public var selectedTemplateKeys: [RecommendedPuzTemplateKey]
    public var customDraft: CustomRoutineDraft?

    public var hasAnyRoutine: Bool {
        !selectedTemplateKeys.isEmpty || customDraft != nil
    }

    public init(selectedTemplateKeys: [RecommendedPuzTemplateKey], customDraft: CustomRoutineDraft?) {
        self.selectedTemplateKeys = selectedTemplateKeys
        self.customDraft = customDraft
    }
}

public enum OnboardingRoutineFactory {
    public static func routines(
        from selection: OnboardingSelection,
        templates: [RecommendedPuzTemplate] = RecommendedPuzTemplate.defaults
    ) -> [Routine] {
        let selectedKeys = Set(selection.selectedTemplateKeys)
        var routines = templates
            .filter { selectedKeys.contains($0.key) }
            .map(routine(from:))

        if let customDraft = selection.customDraft {
            routines.append(routine(from: customDraft))
        }

        return routines
    }

    public static func routine(from template: RecommendedPuzTemplate) -> Routine {
        let times = template.dailyTimes.isEmpty ? [DailyTime(hour: 9, minute: 0)] : template.dailyTimes
        let firstTime = times[0]
        return Routine(
            title: template.title,
            actionType: template.actionType,
            schedule: .fixedTime(firstTime),
            countdownSeconds: template.countdownSeconds,
            snoozePolicy: template.snoozePolicy,
            isEnabled: true,
            activeWeekdays: Set(Weekday.allCases),
            windows: times.map { RoutineWindow(label: template.title, start: $0, end: $0) },
            frequency: RoutineFrequency(runsPerDay: times.count, minimumGapMinutes: 0, distribution: .evenlySpread),
            exactDailyTimes: times
        )
    }

    public static func routine(from draft: CustomRoutineDraft) -> Routine {
        let times = customExactTimes(from: draft)
        let title = draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom puz" : draft.name
        return Routine(
            title: title,
            actionType: .exercise,
            schedule: .fixedTime(times[0]),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            isEnabled: true,
            activeWeekdays: Set(Weekday.allCases),
            windows: times.map { RoutineWindow(label: title, start: $0, end: $0) },
            frequency: RoutineFrequency(runsPerDay: draft.dailyCount, minimumGapMinutes: 0, distribution: .evenlySpread),
            exactDailyTimes: times,
            glyphSymbolName: draft.glyphSymbolName
        )
    }

    private static func customExactTimes(from draft: CustomRoutineDraft) -> [DailyTime] {
        guard draft.dailyCount > 1 else { return [draft.dailyTime] }
        let startMinutes = draft.dailyTime.hour * 60 + draft.dailyTime.minute
        let latestMinutes = 22 * 60
        let availableMinutes = max(draft.dailyCount - 1, latestMinutes - startMinutes)
        let step = max(1, availableMinutes / (draft.dailyCount - 1))
        return (0..<draft.dailyCount).map { index in
            let minutes = min(23 * 60 + 59, startMinutes + index * step)
            return DailyTime(hour: minutes / 60, minute: minutes % 60)
        }
    }
}

public enum OnboardingActivation {
    public static func runtimeRoutines(from store: RoutineStore) -> [Routine] {
        store.hasCompletedOnboarding ? store.routines : []
    }
}

public enum OnboardingLaunchPolicy {
    public static func shouldAutoOpenSetup(status: OnboardingStatus) -> Bool {
        status == .notStarted
    }
}

public enum RoutineSettingsNormalizer {
    public static func normalized(_ routine: Routine) -> Routine {
        let windows = routine.windows.sortedByStartTime
        let firstWindow = windows.first ?? RoutineWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))
        let exactTimes = preservedExactDailyTimes(for: routine, windows: windows)
        let frequency = exactTimes.map { RoutineFrequency(runsPerDay: $0.count, minimumGapMinutes: 0, distribution: .evenlySpread) } ?? routine.frequency
        let schedule: Schedule
        if let firstExactTime = exactTimes?.first {
            schedule = .fixedTime(firstExactTime)
        } else {
            schedule = .randomWindow(start: firstWindow.start, end: firstWindow.end)
        }

        return Routine(
            id: routine.id,
            title: routine.title,
            actionType: routine.actionType,
            schedule: schedule,
            countdownSeconds: routine.countdownSeconds,
            snoozePolicy: routine.snoozePolicy,
            isEnabled: routine.isEnabled,
            activeWeekdays: routine.activeWeekdays,
            windows: windows,
            frequency: frequency,
            exactDailyTimes: exactTimes,
            glyphSymbolName: routine.glyphSymbolName
        )
    }

    private static func preservedExactDailyTimes(for routine: Routine, windows: [RoutineWindow]) -> [DailyTime]? {
        guard let exactTimes = routine.exactDailyTimes,
              !exactTimes.isEmpty,
              windows.count == exactTimes.count else {
            return nil
        }

        for (window, exactTime) in zip(windows, exactTimes) {
            guard window.start == exactTime,
                  window.end == exactTime else {
                return nil
            }
        }
        return exactTimes
    }
}

public struct OnboardingPreviewItem: Equatable, Hashable {
    public let routineTitle: String
    public let date: Date

    public init(routineTitle: String, date: Date) {
        self.routineTitle = routineTitle
        self.date = date
    }
}

public struct OnboardingPreviewService {
    private let calendar: Calendar
    private let scheduleEngine: ScheduleEngine

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.scheduleEngine = ScheduleEngine(calendar: calendar)
    }

    public func previewToday(selection: OnboardingSelection, after now: Date = Date()) -> [OnboardingPreviewItem] {
        let day = calendar.startOfDay(for: now)
        return OnboardingRoutineFactory.routines(from: selection).flatMap { routine in
            scheduleEngine.availableSlots(for: routine, on: day, after: now).map { slot in
                OnboardingPreviewItem(routineTitle: routine.title, date: slot.scheduledAt)
            }
        }
        .sorted { $0.date < $1.date }
    }
}

public enum RoutineValidationIssue: Equatable, Hashable {
    case noWeekdays
    case noWindows
    case invalidWindow
    case overlappingWindows
    case impossibleFrequency
}

public enum RoutineValidator {
    public static func validationIssue(for routine: Routine) -> RoutineValidationIssue? {
        let windows = routine.windows.sortedByStartTime
        guard !routine.activeWeekdays.isEmpty else { return .noWeekdays }
        guard !windows.isEmpty else { return .noWindows }
        guard windows.allSatisfy({ $0.start.totalMinutes < $0.end.totalMinutes || isExactWindow($0, in: routine) }) else {
            return .invalidWindow
        }
        guard !windows.hasOverlapsByTime else { return .overlappingWindows }

        if routine.exactDailyTimes?.isEmpty == false {
            return nil
        }

        let availableMinutes = windows.reduce(0) { $0 + max(0, $1.end.totalMinutes - $1.start.totalMinutes) }
        let requiredGapMinutes = max(0, routine.frequency.runsPerDay - 1) * routine.frequency.minimumGapMinutes
        guard requiredGapMinutes <= availableMinutes else { return .impossibleFrequency }
        return nil
    }

    private static func isExactWindow(_ window: RoutineWindow, in routine: Routine) -> Bool {
        guard window.start == window.end else { return false }
        if let exactDailyTimes = routine.exactDailyTimes {
            return exactDailyTimes.contains(window.start)
        }
        if case .fixedTime(let time) = routine.schedule {
            return time == window.start
        }
        return false
    }
}

private extension DailyTime {
    var totalMinutes: Int {
        hour * 60 + minute
    }
}

private extension Array where Element == RoutineWindow {
    var sortedByStartTime: [RoutineWindow] {
        sorted {
            if $0.start.totalMinutes == $1.start.totalMinutes {
                return $0.end.totalMinutes < $1.end.totalMinutes
            }
            return $0.start.totalMinutes < $1.start.totalMinutes
        }
    }

    var hasOverlapsByTime: Bool {
        let sorted = sortedByStartTime
        return zip(sorted, sorted.dropFirst()).contains { previous, next in
            next.start.totalMinutes < previous.end.totalMinutes
        }
    }
}
