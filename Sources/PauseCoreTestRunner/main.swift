import Foundation
import PauseCore

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(message: message) }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw TestFailure(message: "\(message) — expected \(expected), got \(actual)")
    }
}

func unwrap<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message: message) }
    return value
}

func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

func makeDate(_ calendar: Calendar, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day, hour: hour, minute: minute).date!
}

let tests: [(String, () throws -> Void)] = [
    ("fixed schedule returns today when time is ahead", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 0)
        let routine = Routine.defaultBurpee(schedule: .fixedTime(DailyTime(hour: 11, minute: 30)))
        let engine = ScheduleEngine(calendar: calendar, randomInt: { range in range.lowerBound })
        let next = try unwrap(engine.nextTriggerDate(for: routine, after: now), "next date should exist")
        try expectEqual(next, makeDate(calendar, year: 2026, month: 5, day: 6, hour: 11, minute: 30), "fixed schedule date")
    }),
    ("fixed schedule returns tomorrow when time passed", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 12, minute: 0)
        let routine = Routine.defaultBurpee(schedule: .fixedTime(DailyTime(hour: 11, minute: 30)))
        let engine = ScheduleEngine(calendar: calendar, randomInt: { range in range.lowerBound })
        let next = try unwrap(engine.nextTriggerDate(for: routine, after: now), "next date should exist")
        try expectEqual(next, makeDate(calendar, year: 2026, month: 5, day: 7, hour: 11, minute: 30), "fixed schedule tomorrow date")
    }),
    ("random window before window uses random offset inside todays window", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 8, minute: 0)
        let routine = Routine.defaultBurpee(schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)))
        let engine = ScheduleEngine(calendar: calendar, randomInt: { _ in 120 })
        let next = try unwrap(engine.nextTriggerDate(for: routine, after: now), "next date should exist")
        try expectEqual(next, makeDate(calendar, year: 2026, month: 5, day: 6, hour: 9, minute: 2), "random date before window")
    }),
    ("random window inside window uses now as lower bound", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 0)
        let routine = Routine.defaultBurpee(schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)))
        let engine = ScheduleEngine(calendar: calendar, randomInt: { _ in 300 })
        let next = try unwrap(engine.nextTriggerDate(for: routine, after: now), "next date should exist")
        try expectEqual(next, makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 5), "random date inside window")
    }),
    ("random window after window uses tomorrow window", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 19, minute: 0)
        let routine = Routine.defaultBurpee(schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)))
        let engine = ScheduleEngine(calendar: calendar, randomInt: { _ in 60 })
        let next = try unwrap(engine.nextTriggerDate(for: routine, after: now), "next date should exist")
        try expectEqual(next, makeDate(calendar, year: 2026, month: 5, day: 7, hour: 9, minute: 1), "random date after window")
    }),
    ("runtime scheduling ignores completion history and stays in todays remaining window", {
        let calendar = makeCalendar()
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 0)
        let routine = Routine(
            id: routineID,
            title: "버피",
            actionType: .burpee,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 600,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 60)
        )
        let completion = CompletionRecord(
            routineID: routineID,
            completedAt: makeDate(calendar, year: 2026, month: 5, day: 6, hour: 9, minute: 30),
            snoozeCount: 0,
            wasInterrupted: false
        )
        let engine = ScheduleEngine(calendar: calendar, randomInt: { _ in 300 })
        let next = try unwrap(
            engine.nextRuntimeTrigger(for: [routine], completionRecords: [completion], after: now),
            "runtime trigger should exist"
        )
        try expectEqual(next.routine.id, routineID, "runtime trigger routine")
        try expectEqual(next.date, makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 5), "runtime trigger should stay today")
    }),
    ("disabled routine has no trigger", {
        var routine = Routine.defaultBurpee()
        routine.isEnabled = false
        let engine = ScheduleEngine(calendar: makeCalendar())
        try expect(engine.nextTriggerDate(for: routine, after: Date()) == nil, "disabled routine should not schedule")
    }),
    ("default burpee routine allows two one-hour snoozes", {
        let routine = Routine.defaultBurpee()
        var engine = SnoozeEngine(policy: routine.snoozePolicy)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try expect(engine.canSnooze, "default should allow snooze")
        try expectEqual(engine.remainingCount, 2, "initial snooze count")
        let first = try unwrap(engine.consumeSnooze(now: now), "first snooze should exist")
        try expectEqual(first, now.addingTimeInterval(3_600), "first snooze time")
        try expectEqual(engine.remainingCount, 1, "remaining after first snooze")
        let second = try unwrap(engine.consumeSnooze(now: first), "second snooze should exist")
        try expectEqual(second, first.addingTimeInterval(3_600), "second snooze time")
        try expectEqual(engine.remainingCount, 0, "remaining after second snooze")
        try expect(!engine.canSnooze, "third snooze should be blocked")
        try expect(engine.consumeSnooze(now: second) == nil, "third snooze should return nil")
    }),
    ("zero snooze policy never allows snooze", {
        var engine = SnoozeEngine(policy: SnoozePolicy(maxCount: 0, intervalMinutes: 60))
        try expect(!engine.canSnooze, "zero policy should block snooze")
        try expect(engine.consumeSnooze(now: Date()) == nil, "zero policy returns nil")
    }),
    ("snooze prompt exposes one minute thirty minutes and random choices", {
        try expectEqual(SnoozeDelayOption.promptOptions.map(\.buttonTitle), ["1분 후", "30분 후", "랜덤"], "prompt snooze button titles")
        try expectEqual(SnoozeDelayOption.oneMinute.delaySeconds(), 60, "one minute delay")
        try expectEqual(SnoozeDelayOption.thirtyMinutes.delaySeconds(), 1_800, "thirty minute delay")
        try expectEqual(SnoozeDelayOption.random.delaySeconds(randomMinutes: { range in
            try! expectEqual(range.lowerBound, 2, "random lower bound")
            try! expectEqual(range.upperBound, 29, "random upper bound")
            return 17
        }), 1_020, "random delay")
    }),
    ("manual time input keeps digits and clamps to time ranges", {
        try expectEqual(TimeInputSanitizer.digitsOnly("9a:5"), "95", "digits-only filtering")
        try expectEqual(TimeInputSanitizer.clampedValue(from: "", fallback: 7, range: 0...23), 7, "empty input keeps fallback")
        try expectEqual(TimeInputSanitizer.clampedValue(from: "31", fallback: 7, range: 0...23), 23, "hour upper clamp")
        try expectEqual(TimeInputSanitizer.clampedValue(from: "-3", fallback: 7, range: 0...23), 3, "minus sign is ignored as non-digit")
        try expectEqual(TimeInputSanitizer.clampedValue(from: "72", fallback: 10, range: 0...59), 59, "minute upper clamp")
    }),
    ("snooze prompt state reports remaining count and limit", {
        let policy = SnoozePolicy(maxCount: 3, intervalMinutes: 60)
        let oneUsed = SnoozePromptState(policy: policy, usedCount: 1)
        try expectEqual(oneUsed.remainingCount, 2, "remaining after one used")
        try expect(oneUsed.canSnooze, "one used should still allow snooze")
        try expectEqual(oneUsed.remainingText, "미루기 2회 남음", "remaining copy")

        let exhausted = SnoozePromptState(policy: policy, usedCount: 3)
        try expectEqual(exhausted.remainingCount, 0, "remaining at limit")
        try expect(!exhausted.canSnooze, "at limit should disable snooze")
        try expectEqual(exhausted.remainingText, "미루기 0회 남음", "empty remaining copy")

        let overUsed = SnoozePromptState(policy: policy, usedCount: 8)
        try expectEqual(overUsed.remainingCount, 0, "over limit should clamp remaining")
        try expectEqual(SnoozePolicy(maxCount: -2, intervalMinutes: 0).maxCount, 0, "negative max clamp")
    }),
    ("default routine still stores a compatibility snooze policy", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let routine = try unwrap(store.routines.first, "default routine should exist")
        try expectEqual(routine.title, "버피", "default title")
        try expectEqual(routine.actionType, .burpee, "default action type")
        try expectEqual(routine.countdownSeconds, 600, "default countdown")
        try expectEqual(routine.snoozePolicy.maxCount, 2, "default snooze max")
        try expectEqual(routine.snoozePolicy.intervalMinutes, 60, "default snooze interval")
        try expectEqual(routine.schedule, .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)), "default schedule")
    }),
    ("routines persist across store instances", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        var routine = Routine.defaultBurpee()
        routine.title = "물 마시기"
        store.saveRoutines([routine])
        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.routines.first?.title, "물 마시기", "persisted routine title")
    }),
    ("completion records persist across store instances", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let routineID = UUID()
        let record = CompletionRecord(routineID: routineID, completedAt: Date(timeIntervalSince1970: 1_800_000_000), snoozeCount: 2, wasInterrupted: false)
        store.appendCompletionRecord(record)
        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.completionRecords, [record], "persisted completion records")
    })
]

func makeDefaults() -> UserDefaults {
    let suiteName = "PauseTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

var failures: [String] = []
for (name, test) in tests {
    do {
        try test()
        print("✅ \(name)")
    } catch {
        failures.append("❌ \(name): \(error)")
    }
}

if failures.isEmpty {
    print("All \(tests.count) tests passed")
} else {
    print(failures.joined(separator: "\n"))
    exit(1)
}
