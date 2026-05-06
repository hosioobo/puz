import Foundation

public enum ActionType: String, Codable, CaseIterable, Equatable, Hashable {
    case burpee
    case standUp
    case drinkWater
    case stretch
    case exercise

    public var displayName: String {
        switch self {
        case .burpee: return "버피"
        case .standUp: return "일어나기"
        case .drinkWater: return "물 마시기"
        case .stretch: return "스트레칭"
        case .exercise: return "운동"
        }
    }
}

public struct DailyTime: Codable, Equatable, Hashable, CustomStringConvertible {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public var description: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

public enum TimeInputSanitizer {
    public static func digitsOnly(_ text: String) -> String {
        String(text.filter { $0.isWholeNumber })
    }

    public static func clampedValue(from text: String, fallback: Int, range: ClosedRange<Int>) -> Int {
        let fallback = min(max(fallback, range.lowerBound), range.upperBound)
        let digits = digitsOnly(text)
        guard let value = Int(digits) else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

public enum Schedule: Codable, Equatable, Hashable {
    case fixedTime(DailyTime)
    case randomWindow(start: DailyTime, end: DailyTime)

    public var displayName: String {
        switch self {
        case .fixedTime(let time):
            return "지정 시각 \(time)"
        case .randomWindow(let start, let end):
            return "랜덤 구간 \(start)–\(end)"
        }
    }
}

public struct SnoozePolicy: Codable, Equatable, Hashable {
    public var maxCount: Int
    public var intervalMinutes: Int

    public init(maxCount: Int, intervalMinutes: Int) {
        self.maxCount = max(0, maxCount)
        self.intervalMinutes = max(1, intervalMinutes)
    }
}

public enum SnoozeDelayOption: String, Codable, CaseIterable, Equatable, Hashable {
    case oneMinute
    case thirtyMinutes
    case random

    public static let randomMinuteRange: ClosedRange<Int> = 2...29
    public static let promptOptions: [SnoozeDelayOption] = [.oneMinute, .thirtyMinutes, .random]

    public var buttonTitle: String {
        switch self {
        case .oneMinute:
            return "1분 후"
        case .thirtyMinutes:
            return "30분 후"
        case .random:
            return "랜덤"
        }
    }

    public func delaySeconds(randomMinutes: (ClosedRange<Int>) -> Int = { Int.random(in: $0) }) -> Int {
        switch self {
        case .oneMinute:
            return 60
        case .thirtyMinutes:
            return 30 * 60
        case .random:
            return randomMinutes(Self.randomMinuteRange) * 60
        }
    }
}

public struct SnoozePromptState: Equatable, Hashable {
    public let policy: SnoozePolicy
    public let usedCount: Int

    public init(policy: SnoozePolicy, usedCount: Int) {
        self.policy = policy
        self.usedCount = max(0, usedCount)
    }

    public var remainingCount: Int {
        max(0, policy.maxCount - usedCount)
    }

    public var canSnooze: Bool {
        remainingCount > 0
    }

    public var remainingText: String {
        "미루기 \(remainingCount)회 남음"
    }
}

public struct Routine: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public var title: String
    public var actionType: ActionType
    public var schedule: Schedule
    public var countdownSeconds: Int
    public var snoozePolicy: SnoozePolicy
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        actionType: ActionType,
        schedule: Schedule,
        countdownSeconds: Int,
        snoozePolicy: SnoozePolicy,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? actionType.displayName : title
        self.actionType = actionType
        self.schedule = schedule
        self.countdownSeconds = max(1, countdownSeconds)
        self.snoozePolicy = snoozePolicy
        self.isEnabled = isEnabled
    }

    public static func defaultBurpee(
        schedule: Schedule = .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))
    ) -> Routine {
        Routine(
            title: "버피",
            actionType: .burpee,
            schedule: schedule,
            countdownSeconds: 10 * 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 60),
            isEnabled: true
        )
    }
}

public struct CompletionRecord: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let routineID: UUID
    public let completedAt: Date
    public let snoozeCount: Int
    public let wasInterrupted: Bool

    public init(
        id: UUID = UUID(),
        routineID: UUID,
        completedAt: Date,
        snoozeCount: Int,
        wasInterrupted: Bool
    ) {
        self.id = id
        self.routineID = routineID
        self.completedAt = completedAt
        self.snoozeCount = max(0, snoozeCount)
        self.wasInterrupted = wasInterrupted
    }
}

public struct ScheduledRoutine: Equatable, Hashable {
    public let routine: Routine
    public let date: Date

    public init(routine: Routine, date: Date) {
        self.routine = routine
        self.date = date
    }
}

public struct ScheduleEngine {
    public typealias RandomInt = (ClosedRange<Int>) -> Int

    private let calendar: Calendar
    private let randomInt: RandomInt

    public init(calendar: Calendar = .current, randomInt: @escaping RandomInt = { Int.random(in: $0) }) {
        self.calendar = calendar
        self.randomInt = randomInt
    }

    public func nextTriggerDate(for routine: Routine, after now: Date = Date()) -> Date? {
        guard routine.isEnabled else { return nil }

        switch routine.schedule {
        case .fixedTime(let time):
            return nextFixedTime(time, after: now)
        case .randomWindow(let start, let end):
            return nextRandomWindow(start: start, end: end, after: now)
        }
    }

    public func nextRuntimeTrigger(
        for routines: [Routine],
        completionRecords: [CompletionRecord] = [],
        after now: Date = Date()
    ) -> ScheduledRoutine? {
        routines.compactMap { routine -> ScheduledRoutine? in
            guard let date = nextTriggerDate(for: routine, after: now) else { return nil }
            return ScheduledRoutine(routine: routine, date: date)
        }
        .min(by: { $0.date < $1.date })
    }

    private func nextFixedTime(_ time: DailyTime, after now: Date) -> Date? {
        guard var candidate = date(for: time, onDayContaining: now) else { return nil }
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86_400)
        }
        return candidate
    }

    private func nextRandomWindow(start: DailyTime, end: DailyTime, after now: Date) -> Date? {
        guard let todayWindow = windowBounds(start: start, end: end, dayContaining: now) else { return nil }

        let lower: Date
        let upper: Date

        if now < todayWindow.start {
            lower = todayWindow.start
            upper = todayWindow.end
        } else if now <= todayWindow.end {
            lower = now
            upper = todayWindow.end
        } else {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
            guard let tomorrowWindow = windowBounds(start: start, end: end, dayContaining: tomorrow) else { return nil }
            lower = tomorrowWindow.start
            upper = tomorrowWindow.end
        }

        let availableSeconds = max(0, Int(upper.timeIntervalSince(lower)))
        let offset = availableSeconds == 0 ? 0 : randomInt(0...availableSeconds)
        return lower.addingTimeInterval(TimeInterval(offset))
    }

    private func windowBounds(start: DailyTime, end: DailyTime, dayContaining date: Date) -> (start: Date, end: Date)? {
        guard let startDate = self.date(for: start, onDayContaining: date),
              var endDate = self.date(for: end, onDayContaining: date) else {
            return nil
        }
        if endDate <= startDate {
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate.addingTimeInterval(86_400)
        }
        return (startDate, endDate)
    }

    private func date(for time: DailyTime, onDayContaining date: Date) -> Date? {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: startOfDay)
    }
}

public struct SnoozeEngine: Equatable {
    public let policy: SnoozePolicy
    public private(set) var usedCount: Int

    public init(policy: SnoozePolicy, usedCount: Int = 0) {
        self.policy = policy
        self.usedCount = min(max(0, usedCount), policy.maxCount)
    }

    public var remainingCount: Int {
        max(0, policy.maxCount - usedCount)
    }

    public var canSnooze: Bool {
        remainingCount > 0
    }

    public mutating func consumeSnooze(now: Date = Date()) -> Date? {
        guard canSnooze else { return nil }
        usedCount += 1
        return now.addingTimeInterval(TimeInterval(policy.intervalMinutes * 60))
    }

    public mutating func reset() {
        usedCount = 0
    }
}

public final class RoutineStore {
    private enum Key {
        static let routines = "pause.routines"
        static let completionRecords = "pause.completionRecords"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var routines: [Routine] {
        load([Routine].self, key: Key.routines) ?? [Routine.defaultBurpee()]
    }

    public var completionRecords: [CompletionRecord] {
        load([CompletionRecord].self, key: Key.completionRecords) ?? []
    }

    public func saveRoutines(_ routines: [Routine]) {
        save(routines.isEmpty ? [Routine.defaultBurpee()] : routines, key: Key.routines)
    }

    public func saveRoutine(_ routine: Routine) {
        var routines = self.routines
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
        saveRoutines(routines)
    }

    public func appendCompletionRecord(_ record: CompletionRecord) {
        var records = completionRecords
        records.append(record)
        save(records, key: Key.completionRecords)
    }

    public func completions(on day: Date, calendar: Calendar = .current) -> [CompletionRecord] {
        completionRecords.filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
