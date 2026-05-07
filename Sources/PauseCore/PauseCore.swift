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

public enum Weekday: Int, Codable, CaseIterable, Equatable, Hashable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public struct RoutineWindow: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public var label: String
    public var start: DailyTime
    public var end: DailyTime

    public init(id: UUID = UUID(), label: String = "", start: DailyTime, end: DailyTime) {
        self.id = id
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.start = start
        self.end = end
    }

    public static func from(schedule: Schedule) -> RoutineWindow {
        switch schedule {
        case .fixedTime(let time):
            return RoutineWindow(label: "Fixed", start: time, end: time)
        case .randomWindow(let start, let end):
            return RoutineWindow(label: "Window", start: start, end: end)
        }
    }
}

public enum DistributionMode: String, Codable, CaseIterable, Equatable, Hashable {
    case evenlySpread
    case random
}

public struct RoutineFrequency: Codable, Equatable, Hashable {
    public var runsPerDay: Int
    public var minimumGapMinutes: Int
    public var distribution: DistributionMode

    public init(runsPerDay: Int = 1, minimumGapMinutes: Int = 60, distribution: DistributionMode = .evenlySpread) {
        self.runsPerDay = max(1, runsPerDay)
        self.minimumGapMinutes = max(0, minimumGapMinutes)
        self.distribution = distribution
    }
}

public struct VirtualSlot: Equatable, Hashable {
    public let routine: Routine
    public let scheduledAt: Date
    public let slotKey: String
    public let windowID: UUID?
    public let indexInDay: Int

    public init(routine: Routine, scheduledAt: Date, slotKey: String, windowID: UUID?, indexInDay: Int) {
        self.routine = routine
        self.scheduledAt = scheduledAt
        self.slotKey = slotKey
        self.windowID = windowID
        self.indexInDay = max(0, indexInDay)
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

public enum SessionEndAction: String, Codable, CaseIterable, Equatable, Hashable {
    case remindMeLater
    case skipToday
    case justClose
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
    public var activeWeekdays: Set<Weekday>
    public var windows: [RoutineWindow]
    public var frequency: RoutineFrequency

    public init(
        id: UUID = UUID(),
        title: String,
        actionType: ActionType,
        schedule: Schedule,
        countdownSeconds: Int,
        snoozePolicy: SnoozePolicy,
        isEnabled: Bool = true,
        activeWeekdays: Set<Weekday> = Set(Weekday.allCases),
        windows: [RoutineWindow]? = nil,
        frequency: RoutineFrequency = RoutineFrequency()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? actionType.displayName : title
        self.actionType = actionType
        self.schedule = schedule
        self.countdownSeconds = max(1, countdownSeconds)
        self.snoozePolicy = snoozePolicy
        self.isEnabled = isEnabled
        self.activeWeekdays = activeWeekdays.isEmpty ? Set(Weekday.allCases) : activeWeekdays
        let resolvedWindows = windows ?? [RoutineWindow.from(schedule: schedule)]
        self.windows = resolvedWindows.isEmpty ? [RoutineWindow.from(schedule: schedule)] : resolvedWindows
        self.frequency = frequency
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

    public static func defaultRoutines() -> [Routine] {
        let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let everyday = Set(Weekday.allCases)
        let workdayWindow = RoutineWindow(
            label: "Workday",
            start: DailyTime(hour: 9, minute: 0),
            end: DailyTime(hour: 18, minute: 0)
        )
        let workdaySchedule = Schedule.randomWindow(start: workdayWindow.start, end: workdayWindow.end)

        return [
            Routine(
                title: "Stretch",
                actionType: .stretch,
                schedule: workdaySchedule,
                countdownSeconds: 10 * 60,
                snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 60),
                isEnabled: true,
                activeWeekdays: workdays,
                windows: [workdayWindow],
                frequency: RoutineFrequency(runsPerDay: 1, minimumGapMinutes: 60, distribution: .evenlySpread)
            ),
            Routine(
                title: "Hydrate",
                actionType: .drinkWater,
                schedule: workdaySchedule,
                countdownSeconds: 60,
                snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
                isEnabled: true,
                activeWeekdays: everyday,
                windows: [workdayWindow],
                frequency: RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 90, distribution: .evenlySpread)
            ),
            Routine(
                title: "Stand up",
                actionType: .standUp,
                schedule: workdaySchedule,
                countdownSeconds: 5 * 60,
                snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 45),
                isEnabled: true,
                activeWeekdays: workdays,
                windows: [workdayWindow],
                frequency: RoutineFrequency(runsPerDay: 2, minimumGapMinutes: 120, distribution: .evenlySpread)
            )
        ]
    }
}

public struct CompletionRecord: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let routineID: UUID
    public let completedAt: Date
    public let snoozeCount: Int
    public let wasInterrupted: Bool
    public let scheduledAt: Date?
    public let slotKey: String?

    public init(
        id: UUID = UUID(),
        routineID: UUID,
        completedAt: Date,
        snoozeCount: Int,
        wasInterrupted: Bool,
        scheduledAt: Date? = nil,
        slotKey: String? = nil
    ) {
        self.id = id
        self.routineID = routineID
        self.completedAt = completedAt
        self.snoozeCount = max(0, snoozeCount)
        self.wasInterrupted = wasInterrupted
        self.scheduledAt = scheduledAt
        self.slotKey = slotKey
    }
}

public struct SkipRecord: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let routineID: UUID
    public let scheduledDate: Date
    public let skippedAt: Date
    public let scheduledAt: Date?
    public let slotKey: String?

    public init(
        id: UUID = UUID(),
        routineID: UUID,
        scheduledDate: Date,
        skippedAt: Date,
        scheduledAt: Date? = nil,
        slotKey: String? = nil
    ) {
        self.id = id
        self.routineID = routineID
        self.scheduledDate = scheduledDate
        self.skippedAt = skippedAt
        self.scheduledAt = scheduledAt
        self.slotKey = slotKey
    }
}

public struct ScheduledRoutine: Equatable, Hashable {
    public let routine: Routine
    public let date: Date
    public let slot: VirtualSlot?

    public init(routine: Routine, date: Date, slot: VirtualSlot? = nil) {
        self.routine = routine
        self.date = date
        self.slot = slot
    }

    public init(slot: VirtualSlot) {
        self.routine = slot.routine
        self.date = slot.scheduledAt
        self.slot = slot
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

    public func slots(for routine: Routine, on day: Date) -> [VirtualSlot] {
        guard routine.isEnabled,
              let weekday = Weekday(rawValue: calendar.component(.weekday, from: day)),
              routine.activeWeekdays.contains(weekday) else {
            return []
        }

        let windows = routine.windows.compactMap { window -> SlotWindowBounds? in
            guard let start = date(for: window.start, onDayContaining: day),
                  let end = date(for: window.end, onDayContaining: day),
                  end >= start else {
                return nil
            }
            guard end > start || isFixedTimeWindow(window, for: routine.schedule) else {
                return nil
            }
            return SlotWindowBounds(id: window.id, start: start, end: end)
        }
        .sorted(by: { $0.start < $1.start })

        guard !windows.isEmpty else { return [] }

        let totalSeconds = windows.reduce(0) { total, window in
            total + max(0, Int(window.end.timeIntervalSince(window.start)))
        }
        guard totalSeconds >= 0 else { return [] }

        let offsets = offsets(
            count: routine.frequency.runsPerDay,
            totalSeconds: totalSeconds,
            minimumGapSeconds: routine.frequency.minimumGapMinutes * 60,
            distribution: routine.frequency.distribution,
            seed: randomSeed(for: routine, on: day, windows: windows)
        )

        return offsets.enumerated().compactMap { offsetIndex, offset in
            guard let placement = placement(forOffset: offset, in: windows) else { return nil }
            let indexInDay = offsetIndex + 1
            return VirtualSlot(
                routine: routine,
                scheduledAt: placement.date,
                slotKey: slotKey(for: routine, on: day, indexInDay: indexInDay),
                windowID: placement.windowID,
                indexInDay: indexInDay
            )
        }
    }

    public func availableSlots(
        for routine: Routine,
        on day: Date,
        completionRecords: [CompletionRecord] = [],
        skipRecords: [SkipRecord] = [],
        after now: Date
    ) -> [VirtualSlot] {
        guard !hasSkipToday(for: routine, on: day, skipRecords: skipRecords) else { return [] }
        return slots(for: routine, on: day).filter { slot in
            slot.scheduledAt > now && !isCompleted(slot, completionRecords: completionRecords)
        }
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
        skipRecords: [SkipRecord] = [],
        after now: Date = Date()
    ) -> ScheduledRoutine? {
        let today = calendar.startOfDay(for: now)
        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let afterDate = dayOffset == 0 ? now : day.addingTimeInterval(-1)
            let candidates = routines.flatMap { routine in
                availableSlots(
                    for: routine,
                    on: day,
                    completionRecords: completionRecords,
                    skipRecords: skipRecords,
                    after: afterDate
                )
            }
            if let slot = candidates.min(by: { $0.scheduledAt < $1.scheduledAt }) {
                return ScheduledRoutine(slot: slot)
            }
        }
        return nil
    }

    private struct SlotWindowBounds {
        let id: UUID
        let start: Date
        let end: Date
    }

    private func isFixedTimeWindow(_ window: RoutineWindow, for schedule: Schedule) -> Bool {
        guard case .fixedTime(let time) = schedule else { return false }
        return window.start == time && window.end == time
    }

    private func offsets(
        count: Int,
        totalSeconds: Int,
        minimumGapSeconds: Int,
        distribution: DistributionMode,
        seed: String
    ) -> [Int] {
        guard count > 0 else { return [] }
        guard totalSeconds > 0 else { return [0] }

        let rawOffsets: [Int]
        switch distribution {
        case .evenlySpread:
            rawOffsets = evenlySpreadOffsets(count: count, totalSeconds: totalSeconds, minimumGapSeconds: minimumGapSeconds)
        case .random:
            rawOffsets = deterministicRandomOffsets(
                count: count,
                totalSeconds: totalSeconds,
                minimumGapSeconds: minimumGapSeconds,
                seed: seed
            )
        }

        return rawOffsets.reduce(into: []) { accepted, offset in
            guard let previous = accepted.last else {
                accepted.append(offset)
                return
            }
            if offset - previous >= minimumGapSeconds {
                accepted.append(offset)
            }
        }
    }

    private func evenlySpreadOffsets(count: Int, totalSeconds: Int, minimumGapSeconds: Int) -> [Int] {
        guard count > 1 else { return [totalSeconds / 2] }

        let centerStep = Double(totalSeconds) / Double(count + 1)
        var offsets = (1...count).map { index in
            Int((Double(index) * centerStep).rounded())
        }

        if violatesMinimumGap(offsets, minimumGapSeconds: minimumGapSeconds) {
            let requiredSeconds = minimumGapSeconds * (count - 1)
            if requiredSeconds <= totalSeconds {
                let startOffset = (totalSeconds - requiredSeconds) / 2
                offsets = (0..<count).map { startOffset + ($0 * minimumGapSeconds) }
            }
        }

        return offsets
    }

    private func deterministicRandomOffsets(count: Int, totalSeconds: Int, minimumGapSeconds: Int, seed: String) -> [Int] {
        guard count > 1 else {
            return [Int(stableHash("\(seed).single") % UInt64(totalSeconds + 1))]
        }

        var accepted: [Int] = []
        let maxAttempts = max(200, count * 200)
        var attempt = 0
        while accepted.count < count && attempt < maxAttempts {
            let candidate = Int(stableHash("\(seed).\(attempt)") % UInt64(totalSeconds + 1))
            if canAcceptRandomOffset(candidate, into: accepted, minimumGapSeconds: minimumGapSeconds) {
                accepted.append(candidate)
            }
            attempt += 1
        }

        if accepted.count < count {
            for offset in evenlySpreadOffsets(count: count, totalSeconds: totalSeconds, minimumGapSeconds: minimumGapSeconds) {
                if canAcceptRandomOffset(offset, into: accepted, minimumGapSeconds: minimumGapSeconds) {
                    accepted.append(offset)
                }
                if accepted.count == count { break }
            }
        }

        return accepted.sorted()
    }

    private func canAcceptRandomOffset(_ candidate: Int, into accepted: [Int], minimumGapSeconds: Int) -> Bool {
        !accepted.contains { existing in
            existing == candidate || abs(existing - candidate) < minimumGapSeconds
        }
    }

    private func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private func violatesMinimumGap(_ offsets: [Int], minimumGapSeconds: Int) -> Bool {
        guard minimumGapSeconds > 0, offsets.count > 1 else { return false }
        return zip(offsets, offsets.dropFirst()).contains { previous, next in
            next - previous < minimumGapSeconds
        }
    }

    private func placement(forOffset offset: Int, in windows: [SlotWindowBounds]) -> (date: Date, windowID: UUID)? {
        var remaining = max(0, offset)
        for window in windows {
            let duration = max(0, Int(window.end.timeIntervalSince(window.start)))
            if remaining <= duration {
                return (window.start.addingTimeInterval(TimeInterval(remaining)), window.id)
            }
            remaining -= duration
        }
        guard let last = windows.last else { return nil }
        return (last.end, last.id)
    }

    private func slotKey(for routine: Routine, on day: Date, indexInDay: Int) -> String {
        "\(routine.id.uuidString).\(dateStamp(for: day)).\(indexInDay)"
    }

    private func randomSeed(for routine: Routine, on day: Date, windows: [SlotWindowBounds]) -> String {
        let windowSeed = windows.map { window in
            "\(window.id.uuidString):\(Int(window.start.timeIntervalSince1970)):\(Int(window.end.timeIntervalSince1970))"
        }.joined(separator: "|")
        return [
            routine.id.uuidString,
            dateStamp(for: day),
            String(routine.frequency.runsPerDay),
            String(routine.frequency.minimumGapMinutes),
            windowSeed
        ].joined(separator: ".")
    }

    private func dateStamp(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func nextRuntimeTriggerDate(for routine: Routine, after now: Date, skipRecords: [SkipRecord]) -> Date? {
        var searchDate = now
        for _ in 0..<14 {
            guard let candidate = nextTriggerDate(for: routine, after: searchDate) else { return nil }
            if isSkipped(candidate, for: routine, skipRecords: skipRecords) {
                searchDate = startOfNextDay(after: candidate)
                continue
            }
            return candidate
        }
        return nil
    }

    private func isSkipped(_ candidate: Date, for routine: Routine, skipRecords: [SkipRecord]) -> Bool {
        hasSkipToday(for: routine, on: candidate, skipRecords: skipRecords)
    }

    private func hasSkipToday(for routine: Routine, on day: Date, skipRecords: [SkipRecord]) -> Bool {
        skipRecords.contains { record in
            record.routineID == routine.id && calendar.isDate(record.scheduledDate, inSameDayAs: day)
        }
    }

    private func isCompleted(_ slot: VirtualSlot, completionRecords: [CompletionRecord]) -> Bool {
        completionRecords.contains { record in
            guard record.routineID == slot.routine.id else { return false }
            if let slotKey = record.slotKey {
                return slotKey == slot.slotKey
            }
            if let scheduledAt = record.scheduledAt {
                return scheduledAt == slot.scheduledAt
            }
            return false
        }
    }

    private func startOfNextDay(after date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
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
        static let skipRecords = "pause.skipRecords"
        static let storeVersion = "pause.storeVersion"
    }

    private static let currentStoreVersion = 2

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var routines: [Routine] {
        guard defaults.data(forKey: Key.routines) != nil else {
            return bootstrapDefaultRoutines()
        }

        guard defaults.integer(forKey: Key.storeVersion) == Self.currentStoreVersion,
              let routines = load([Routine].self, key: Key.routines) else {
            return bootstrapDefaultRoutines()
        }

        return routines
    }

    public var completionRecords: [CompletionRecord] {
        load([CompletionRecord].self, key: Key.completionRecords) ?? []
    }

    public var skipRecords: [SkipRecord] {
        load([SkipRecord].self, key: Key.skipRecords) ?? []
    }

    public func saveRoutines(_ routines: [Routine]) {
        persistRoutines(routines)
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

    public func replaceRoutines(_ routines: [Routine]) {
        saveRoutines(routines)
    }

    public func deleteRoutine(id: UUID) {
        saveRoutines(routines.filter { $0.id != id })
    }

    @discardableResult
    public func duplicateRoutine(id: UUID) -> Routine? {
        guard let original = routines.first(where: { $0.id == id }) else { return nil }
        let duplicate = Routine(
            title: "\(original.title) copy",
            actionType: original.actionType,
            schedule: original.schedule,
            countdownSeconds: original.countdownSeconds,
            snoozePolicy: original.snoozePolicy,
            isEnabled: original.isEnabled,
            activeWeekdays: original.activeWeekdays,
            windows: original.windows.map { window in
                RoutineWindow(label: window.label, start: window.start, end: window.end)
            },
            frequency: original.frequency
        )
        var routines = self.routines
        routines.append(duplicate)
        saveRoutines(routines)
        return duplicate
    }

    public func setRoutineEnabled(id: UUID, isEnabled: Bool) {
        var routines = self.routines
        guard let index = routines.firstIndex(where: { $0.id == id }) else { return }
        routines[index].isEnabled = isEnabled
        saveRoutines(routines)
    }

    public func appendCompletionRecord(_ record: CompletionRecord) {
        var records = completionRecords
        records.append(record)
        save(records, key: Key.completionRecords)
    }

    public func appendSkipRecord(_ record: SkipRecord) {
        var records = skipRecords
        records.append(record)
        save(records, key: Key.skipRecords)
    }

    public func completions(on day: Date, calendar: Calendar = .current) -> [CompletionRecord] {
        completionRecords.filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
    }

    public func skips(on day: Date, calendar: Calendar = .current) -> [SkipRecord] {
        skipRecords.filter { calendar.isDate($0.scheduledDate, inSameDayAs: day) }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func bootstrapDefaultRoutines() -> [Routine] {
        let routines = Routine.defaultRoutines()
        persistRoutines(routines)
        return routines
    }

    private func persistRoutines(_ routines: [Routine]) {
        save(routines, key: Key.routines)
        defaults.set(Self.currentStoreVersion, forKey: Key.storeVersion)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
