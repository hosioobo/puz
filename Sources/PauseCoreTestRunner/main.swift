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

func sourceText(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

let tests: [(String, () throws -> Void)] = [
    ("v2 routine scheduling models expose stable basics", {
        let calendar = makeCalendar()
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let windowID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let weekdays: Set<Weekday> = [.monday, .wednesday, .friday]
        let window = RoutineWindow(
            id: windowID,
            label: "Workday",
            start: DailyTime(hour: 9, minute: 0),
            end: DailyTime(hour: 18, minute: 0)
        )
        let frequency = RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 90, distribution: .evenlySpread)
        let routine = Routine(
            id: routineID,
            title: "Stretch",
            actionType: .stretch,
            schedule: .randomWindow(start: window.start, end: window.end),
            countdownSeconds: 600,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 60),
            isEnabled: true,
            activeWeekdays: weekdays,
            windows: [window],
            frequency: frequency
        )
        let scheduledAt = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 14, minute: 0)
        let slot = VirtualSlot(
            routine: routine,
            scheduledAt: scheduledAt,
            slotKey: "\(routineID.uuidString).2026-05-06.1",
            windowID: windowID,
            indexInDay: 1
        )

        try expectEqual(Weekday.sunday.rawValue, 1, "weekday raw values match Calendar weekday")
        try expectEqual(Weekday.friday.rawValue, 6, "Friday raw value")
        try expectEqual(routine.activeWeekdays, weekdays, "routine active weekdays")
        try expectEqual(routine.windows, [window], "routine windows")
        try expectEqual(routine.frequency, frequency, "routine frequency")
        try expectEqual(slot.routine.id, routineID, "slot routine identity")
        try expectEqual(slot.scheduledAt, scheduledAt, "slot scheduled date")
        try expectEqual(slot.indexInDay, 1, "slot index")
    }),
    ("virtual slot projection skips disabled and inactive weekdays", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let engine = ScheduleEngine(calendar: calendar)
        var inactive = Routine.defaultRoutines()[0]
        inactive.activeWeekdays = [.monday]
        try expectEqual(engine.slots(for: inactive, on: day), [], "inactive weekday should produce no slots")

        var disabled = Routine.defaultRoutines()[0]
        disabled.isEnabled = false
        try expectEqual(engine.slots(for: disabled, on: day), [], "disabled routine should produce no slots")
    }),
    ("virtual slot projection evenly spreads runs inside a window", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
        let windowID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
        let routine = Routine(
            id: routineID,
            title: "Hydrate",
            actionType: .drinkWater,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(id: windowID, label: "Workday", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 90, distribution: .evenlySpread)
        )
        let engine = ScheduleEngine(calendar: calendar)
        let slots = engine.slots(for: routine, on: day)
        try expectEqual(slots.map(\.scheduledAt), [
            makeDate(calendar, year: 2026, month: 5, day: 6, hour: 11, minute: 15),
            makeDate(calendar, year: 2026, month: 5, day: 6, hour: 13, minute: 30),
            makeDate(calendar, year: 2026, month: 5, day: 6, hour: 15, minute: 45)
        ], "evenly spread slots")
        try expectEqual(slots.map(\.indexInDay), [1, 2, 3], "slot indexes are one-based")
        try expectEqual(slots.map(\.windowID), [windowID, windowID, windowID], "slot window ids")
        try expectEqual(slots.first?.slotKey, "\(routineID.uuidString).2026-05-06.1", "first slot key")
    }),
    ("virtual slot projection respects minimum gap", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let routine = Routine(
            title: "Micro break",
            actionType: .stretch,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 10, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 1, intervalMinutes: 10),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(label: "Short", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 10, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 30, distribution: .evenlySpread)
        )
        let engine = ScheduleEngine(calendar: calendar)
        let slots = engine.slots(for: routine, on: day)
        try expectEqual(slots.map(\.scheduledAt), [
            makeDate(calendar, year: 2026, month: 5, day: 6, hour: 9, minute: 0),
            makeDate(calendar, year: 2026, month: 5, day: 6, hour: 9, minute: 30),
            makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 0)
        ], "minimum-gap fallback slots")
    }),
    ("random slot projection is deterministic but not evenly spread", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
        let randomRoutine = Routine(
            id: routineID,
            title: "Hydrate",
            actionType: .drinkWater,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(label: "Workday", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 90, distribution: .random)
        )
        var evenRoutine = randomRoutine
        evenRoutine.frequency = RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 90, distribution: .evenlySpread)
        let engine = ScheduleEngine(calendar: calendar)
        let first = engine.slots(for: randomRoutine, on: day)
        let second = engine.slots(for: randomRoutine, on: day)
        let even = engine.slots(for: evenRoutine, on: day)
        try expectEqual(first.map(\.scheduledAt), second.map(\.scheduledAt), "random slots should be stable for the same input")
        try expectEqual(first.count, 3, "random slots should fill requested count when possible")
        try expect(first.map(\.scheduledAt) != even.map(\.scheduledAt), "random slots should not reuse evenly spread offsets")
        for pair in zip(first, first.dropFirst()) {
            try expect(pair.1.scheduledAt.timeIntervalSince(pair.0.scheduledAt) >= 90 * 60, "random slots respect minimum gap")
        }
    }),
    ("available slots exclude completed and past slots", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000106")!
        let routine = Routine(
            id: routineID,
            title: "Hydrate",
            actionType: .drinkWater,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(label: "Workday", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 90, distribution: .evenlySpread)
        )
        let engine = ScheduleEngine(calendar: calendar)
        let slots = engine.slots(for: routine, on: day)
        let completion = CompletionRecord(
            routineID: routineID,
            completedAt: makeDate(calendar, year: 2026, month: 5, day: 6, hour: 13, minute: 45),
            snoozeCount: 0,
            wasInterrupted: false,
            scheduledAt: slots[1].scheduledAt,
            slotKey: slots[1].slotKey
        )
        let available = engine.availableSlots(
            for: routine,
            on: day,
            completionRecords: [completion],
            skipRecords: [],
            after: makeDate(calendar, year: 2026, month: 5, day: 6, hour: 12, minute: 0)
        )
        try expectEqual(available.map(\.slotKey), [slots[2].slotKey], "past and completed slots should be filtered")
    }),
    ("available slots skip the whole routine day", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let nextDay = makeDate(calendar, year: 2026, month: 5, day: 7, hour: 0, minute: 0)
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000107")!
        let routine = Routine(
            id: routineID,
            title: "Hydrate",
            actionType: .drinkWater,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            activeWeekdays: Set(Weekday.allCases),
            windows: [RoutineWindow(label: "Workday", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 2, minimumGapMinutes: 90, distribution: .evenlySpread)
        )
        let engine = ScheduleEngine(calendar: calendar)
        let skip = SkipRecord(
            routineID: routineID,
            scheduledDate: makeDate(calendar, year: 2026, month: 5, day: 6, hour: 11, minute: 0),
            skippedAt: makeDate(calendar, year: 2026, month: 5, day: 6, hour: 11, minute: 5)
        )
        try expectEqual(engine.availableSlots(for: routine, on: day, skipRecords: [skip], after: day), [], "skip today should hide all same-day slots")
        try expectEqual(engine.availableSlots(for: routine, on: nextDay, skipRecords: [skip], after: nextDay).count, 2, "skip today should not hide next-day slots")
    }),
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
    ("runtime scheduling picks the earliest available virtual slot across routines", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 8, minute: 0)
        let earlyID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let lateID = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        let early = Routine(
            id: earlyID,
            title: "Hydrate",
            actionType: .drinkWater,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 12, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(label: "Morning", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 12, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 1, minimumGapMinutes: 60, distribution: .evenlySpread)
        )
        let late = Routine(
            id: lateID,
            title: "Stretch",
            actionType: .stretch,
            schedule: .randomWindow(start: DailyTime(hour: 14, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 600,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 60),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(label: "Afternoon", start: DailyTime(hour: 14, minute: 0), end: DailyTime(hour: 18, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 1, minimumGapMinutes: 60, distribution: .evenlySpread)
        )
        let engine = ScheduleEngine(calendar: calendar)
        let next = try unwrap(engine.nextRuntimeTrigger(for: [late, early], after: now), "runtime trigger should exist")
        try expectEqual(next.routine.id, earlyID, "runtime trigger routine")
        try expectEqual(next.date, makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 30), "runtime trigger date")
        try expectEqual(next.slot?.slotKey, engine.slots(for: early, on: now).first?.slotKey, "runtime trigger slot")
    }),
    ("runtime scheduling keeps legacy fixed-time routines as one virtual slot", {
        let calendar = makeCalendar()
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000205")!
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 10, minute: 0)
        let expected = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 11, minute: 30)
        let routine = Routine(
            id: routineID,
            title: "Fixed stretch",
            actionType: .stretch,
            schedule: .fixedTime(DailyTime(hour: 11, minute: 30)),
            countdownSeconds: 600,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 60),
            activeWeekdays: [.wednesday]
        )
        let engine = ScheduleEngine(calendar: calendar)
        let next = try unwrap(engine.nextRuntimeTrigger(for: [routine], after: now), "fixed-time runtime trigger should exist")
        try expectEqual(next.routine.id, routineID, "fixed-time runtime trigger routine")
        try expectEqual(next.date, expected, "fixed-time runtime trigger date")
        let slot = try unwrap(next.slot, "fixed-time runtime trigger should carry slot metadata")
        try expectEqual(slot.scheduledAt, expected, "fixed-time slot scheduled date")
        try expectEqual(slot.slotKey, "\(routineID.uuidString).2026-05-06.1", "fixed-time slot key")
        try expectEqual(slot.windowID, routine.windows.first?.id, "fixed-time slot window id")
        try expectEqual(slot.indexInDay, 1, "fixed-time slot index")
    }),
    ("runtime scheduling skips completed virtual slots", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 8, minute: 0)
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000203")!
        let routine = Routine(
            id: routineID,
            title: "Hydrate",
            actionType: .drinkWater,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(label: "Workday", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 90, distribution: .evenlySpread)
        )
        let engine = ScheduleEngine(calendar: calendar)
        let firstSlot = try unwrap(engine.slots(for: routine, on: now).first, "first slot should exist")
        let completion = CompletionRecord(
            routineID: routineID,
            completedAt: firstSlot.scheduledAt.addingTimeInterval(60),
            snoozeCount: 0,
            wasInterrupted: false,
            scheduledAt: firstSlot.scheduledAt,
            slotKey: firstSlot.slotKey
        )
        let next = try unwrap(engine.nextRuntimeTrigger(for: [routine], completionRecords: [completion], after: now), "runtime trigger should exist")
        try expectEqual(next.date, makeDate(calendar, year: 2026, month: 5, day: 6, hour: 13, minute: 30), "completed first slot should advance to second")
        try expectEqual(next.slot?.indexInDay, 2, "next slot index")
    }),
    ("runtime scheduling skips a routine for the skipped day", {
        let calendar = makeCalendar()
        let routineID = UUID(uuidString: "00000000-0000-0000-0000-000000000204")!
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 8, minute: 0)
        let routine = Routine(
            id: routineID,
            title: "Stretch",
            actionType: .stretch,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0)),
            countdownSeconds: 600,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 60),
            activeWeekdays: Set(Weekday.allCases),
            windows: [RoutineWindow(label: "Workday", start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 18, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 1, minimumGapMinutes: 60, distribution: .evenlySpread)
        )
        let skip = SkipRecord(
            routineID: routineID,
            scheduledDate: makeDate(calendar, year: 2026, month: 5, day: 6, hour: 13, minute: 30),
            skippedAt: now
        )
        let engine = ScheduleEngine(calendar: calendar)
        let next = try unwrap(engine.nextRuntimeTrigger(for: [routine], skipRecords: [skip], after: now), "runtime trigger should exist after a same-day skip")
        try expectEqual(next.routine.id, routineID, "skipped runtime trigger routine")
        try expectEqual(next.date, makeDate(calendar, year: 2026, month: 5, day: 7, hour: 13, minute: 30), "skip today should move routine to tomorrow")
    }),
    ("runtime scheduling returns nil with no routines", {
        let engine = ScheduleEngine(calendar: makeCalendar())
        try expect(engine.nextRuntimeTrigger(for: [], after: Date()) == nil, "empty routines should not schedule")
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
    ("localization chooses Korean or English from preferred languages", {
        try expectEqual(PuzLanguage.preferred(from: ["ko-KR", "en-US"]), .korean, "Korean locale wins")
        try expectEqual(PuzLanguage.preferred(from: ["en-US", "ko-KR"]), .english, "English locale wins")
        try expectEqual(PuzLanguage.preferred(from: ["fr-FR"]), .english, "unsupported locales fall back to English")
    }),
    ("app surface does not include system notifications", {
        let bannedTokensByFile: [(path: String, tokens: [String])] = [
            (
                "Sources/PauseApp/AppDelegate.swift",
                [
                    "import UserNotifications",
                    "UNUserNotificationCenterDelegate",
                    "UNUserNotificationCenter",
                    "requestAuthorization"
                ]
            ),
            (
                "Sources/PauseApp/RuntimeScheduler.swift",
                [
                    "import UserNotifications",
                    "notificationID",
                    "scheduleNotification",
                    "cancelPendingNotification",
                    "UNMutableNotificationContent",
                    "UNNotificationRequest",
                    "UNTimeIntervalNotificationTrigger",
                    "removePendingNotificationRequests"
                ]
            ),
            (
                "Sources/PauseCore/PuzLocalization.swift",
                [
                    "notificationTitle",
                    "notificationBody"
                ]
            )
        ]

        for check in bannedTokensByFile {
            let text = try sourceText(check.path)
            for token in check.tokens {
                try expect(!text.contains(token), "\(check.path) should not contain \(token)")
            }
        }
    }),
    ("localization exposes Korean and English app copy", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)
        let fixedSchedule = Schedule.fixedTime(DailyTime(hour: 11, minute: 30))
        let routine = Routine.defaultBurpee()

        try expectEqual(english.actionName(.burpee), "Burpee", "English action name")
        try expectEqual(korean.actionName(.burpee), "버피", "Korean action name")
        try expectEqual(english.routineTitle(routine), "Burpee", "English default routine title")
        try expectEqual(korean.routineTitle(routine), "버피", "Korean default routine title")
        try expectEqual(english.scheduleName(fixedSchedule), "Fixed time 11:30", "English schedule copy")
        try expectEqual(korean.scheduleName(fixedSchedule), "지정 시각 11:30", "Korean schedule copy")
        try expectEqual(english.snoozeButtonTitle(.oneMinute), "Snooze 1 min", "English snooze title")
        try expectEqual(korean.snoozeButtonTitle(.oneMinute), "1분 미루기", "Korean snooze title")
        try expectEqual(english.snoozeRemainingText(count: 2), "2 snoozes left", "English snooze remaining")
        try expectEqual(korean.snoozeRemainingText(count: 2), "미루기 2회 남음", "Korean snooze remaining")
        try expectEqual(english.promptTitle(routineTitle: "Burpee"), "Time for Burpee", "English prompt title")
        try expectEqual(korean.promptTitle(routineTitle: "버피"), "버피 할 시간이에요", "Korean prompt title")
        try expectEqual(english.promptSubtitle(scheduledTime: "09:30", duration: "10 min"), "09:30 slot · 10 min countdown", "English prompt subtitle")
        try expectEqual(korean.promptSubtitle(scheduledTime: "09:30", duration: "10분"), "09:30 차례 · 10분 카운트다운", "Korean prompt subtitle")
    }),
    ("localization exposes routine settings and menu v2 copy", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)

        try expectEqual(english.routinesTitle, "Routines", "English routines title")
        try expectEqual(korean.routinesTitle, "루틴", "Korean routines title")
        try expectEqual(english.newRoutineLabel, "New", "English new routine button")
        try expectEqual(korean.newRoutineLabel, "새로 만들기", "Korean new routine button")
        try expectEqual(english.duplicateRoutineLabel, "Duplicate", "English duplicate routine button")
        try expectEqual(korean.duplicateRoutineLabel, "복제", "Korean duplicate routine button")
        try expectEqual(english.basicsSectionTitle, "Basics", "English basics section")
        try expectEqual(korean.basicsSectionTitle, "기본", "Korean basics section")
        try expectEqual(english.whenSectionTitle, "When", "English when section")
        try expectEqual(korean.whenSectionTitle, "언제", "Korean when section")
        try expectEqual(english.howOftenSectionTitle, "How often", "English frequency section")
        try expectEqual(korean.howOftenSectionTitle, "얼마나 자주", "Korean frequency section")
        try expectEqual(english.weekdayShortName(.wednesday), "Wed", "English weekday chip")
        try expectEqual(korean.weekdayShortName(.wednesday), "수", "Korean weekday chip")
        try expectEqual(english.distributionName(.random), "Stable random", "English random distribution")
        try expectEqual(korean.distributionName(.random), "안정적 랜덤", "Korean random distribution")
        try expectEqual(english.menuNext(routineTitle: "Stretch", dateText: "5/7 14:05"), "Next: Stretch at 5/7 14:05", "English v2 menu next")
        try expectEqual(korean.menuNext(routineTitle: "스트레칭", dateText: "5/7 14:05"), "다음: 스트레칭 · 5/7 14:05", "Korean v2 menu next")
        try expectEqual(english.todayProgress(completed: 1, total: 3), "Today: 1/3 completed", "English today progress")
        try expectEqual(korean.todayProgress(completed: 1, total: 3), "오늘: 1/3 완료", "Korean today progress")
        try expectEqual(english.menuNoRoutines, "No routines", "English no routines menu")
        try expectEqual(korean.menuNoRoutines, "루틴 없음", "Korean no routines menu")
        try expectEqual(english.validationInvalidWindow(routineTitle: "Stretch"), "Stretch has a window where start must be before end.", "English window validation")
        try expectEqual(korean.validationInvalidWindow(routineTitle: "스트레칭"), "스트레칭의 시간 구간은 시작이 종료보다 빨라야 해요.", "Korean window validation")
    }),
    ("localization exposes eye rest action copy", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)
        try expectEqual(english.actionName(.eyeRest), "Eye rest", "English eye rest action")
        try expectEqual(korean.actionName(.eyeRest), "눈 쉬기", "Korean eye rest action")
        try expectEqual(english.focusText(for: .eyeRest), "Look far away and blink slowly", "English eye rest focus")
        try expectEqual(korean.focusText(for: .eyeRest), "멀리 보고 천천히 깜빡이기", "Korean eye rest focus")
    }),
    ("light fullscreen localization copy follows the design direction", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)

        try expectEqual(english.startSessionButtonTitle(duration: "10 min"), "Start 10 min", "English start button includes duration")
        try expectEqual(korean.startSessionButtonTitle(duration: "10분"), "10분 시작", "Korean start button includes duration")
        try expectEqual(english.promptActionDescription(actionType: .stretch, minutes: 10), "Take a 10 minute break for shoulders, neck, and hips.", "English prompt description")
        try expectEqual(korean.promptActionDescription(actionType: .stretch, minutes: 10), "어깨, 목, 고관절을 위한 10분 휴식이에요.", "Korean prompt description")
        try expectEqual(english.focusText(for: .stretch), "Shoulders, neck, and hips", "English focus copy")
        try expectEqual(korean.focusText(for: .stretch), "어깨, 목, 고관절", "Korean focus copy")
        try expectEqual(english.activeSessionTitle(for: .stretch), "Stretching", "English active title")
        try expectEqual(korean.activeSessionTitle(for: .stretch), "스트레칭 중", "Korean active title")
        try expectEqual(english.sessionProgressText(minutes: 10), "10 minute session in progress", "English progress hint")
        try expectEqual(korean.sessionProgressText(minutes: 10), "10분 세션 진행 중", "Korean progress hint")
        try expectEqual(english.countdownCompleteTitle, "Nice work", "English completion title")
        try expectEqual(korean.countdownCompleteTitle, "잘했어요", "Korean completion title")
        try expectEqual(english.completionSubtitle(routineTitle: "Stretch", minutes: 10), "Your 10 minute stretch is complete.", "English completion subtitle")
        try expectEqual(korean.completionSubtitle(routineTitle: "스트레칭", minutes: 10), "10분 스트레칭 완료했어요.", "Korean completion subtitle")
        try expectEqual(english.countdownProgressInstruction, "Resume will appear when the timer ends.", "English timer hint")
        try expectEqual(korean.countdownProgressInstruction, "타이머가 끝나면 Resume 버튼이 나타나요.", "Korean timer hint")
        try expectEqual(english.promptHelper, "Start begins the fullscreen countdown. Snooze asks again later. Resume appears after the timer.", "English prompt footer")
        try expectEqual(korean.promptHelper, "시작하면 전체 화면 카운트다운이 진행돼요. 미루기는 나중에 다시 묻고, Resume은 타이머 후에 나타나요.", "Korean prompt footer")
        try expectEqual(english.resumeInstruction, "Press Resume to return to your screen.", "English resume instruction")
        try expectEqual(korean.resumeInstruction, "Resume을 눌러 화면으로 돌아가요.", "Korean resume instruction")
        try expectEqual(english.snoozeButtonSubtitle(.random), "2–29 min", "English random snooze subtitle")
        try expectEqual(korean.snoozeButtonSubtitle(.random), "2–29분", "Korean random snooze subtitle")
        try expectEqual(english.snoozeButtonSubtitle(.oneMinute), nil, "fixed snooze buttons have no subtitle")
        try expectEqual(english.endSessionTitle, "End this session?", "English end-session title")
        try expectEqual(korean.endSessionTitle, "이 세션을 끝낼까요?", "Korean end-session title")
        try expectEqual(english.endSessionActionTitle(.remindMeLater), "Ask me later", "English ask-later action")
        try expectEqual(korean.endSessionActionTitle(.remindMeLater), "나중에 다시 묻기", "Korean ask-later action")
        try expectEqual(english.endSessionActionTitle(.skipToday), "Skip today", "English skip-today action")
        try expectEqual(korean.endSessionActionTitle(.skipToday), "오늘은 건너뛰기", "Korean skip-today action")
        try expectEqual(english.endSessionActionTitle(.justClose), "Close only", "English just-close action")
        try expectEqual(korean.endSessionActionTitle(.justClose), "닫기만", "Korean just-close action")
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
    ("recommended puz templates expose resolved defaults", {
        let templates = RecommendedPuzTemplate.defaults
        try expectEqual(templates.map(\.key), [.hydrate, .stretch, .eyeRest], "template order")
        try expectEqual(templates.map(\.isPreselected), [false, true, false], "only Stretch preselected")
        try expectEqual(templates.map(\.actionType), [.drinkWater, .stretch, .eyeRest], "template actions")
    }),
    ("recommended puz templates use resolved timing defaults", {
        let byKey = Dictionary(uniqueKeysWithValues: RecommendedPuzTemplate.defaults.map { ($0.key, $0) })
        try expectEqual(byKey[.stretch]?.countdownSeconds, 90, "Stretch duration")
        try expectEqual(byKey[.stretch]?.dailyTimes, [DailyTime(hour: 11, minute: 0), DailyTime(hour: 15, minute: 30)], "Stretch times")
        try expectEqual(byKey[.hydrate]?.countdownSeconds, 20, "Hydrate duration")
        try expectEqual(byKey[.hydrate]?.dailyTimes, [DailyTime(hour: 10, minute: 30), DailyTime(hour: 13, minute: 30), DailyTime(hour: 16, minute: 30)], "Hydrate times")
        try expectEqual(byKey[.eyeRest]?.countdownSeconds, 20, "Eye rest duration")
        try expectEqual(byKey[.eyeRest]?.dailyTimes, [DailyTime(hour: 10, minute: 45), DailyTime(hour: 14, minute: 15), DailyTime(hour: 17, minute: 0)], "Eye rest times")
    }),
    ("selected recommended templates convert to routines without persisting", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let selection = OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        let routines = OnboardingRoutineFactory.routines(from: selection, templates: RecommendedPuzTemplate.defaults)

        try expectEqual(store.routines, [], "conversion should not persist")
        try expectEqual(routines.map(\.title), ["Stretch"], "selected routine title")
        try expectEqual(routines.first?.actionType, .stretch, "selected routine action")
        try expectEqual(routines.first?.countdownSeconds, 90, "selected routine duration")
        try expectEqual(routines.first?.snoozePolicy.maxCount, 2, "selected routine max snoozes")
    }),
    ("recommended Stretch routine projects exact default slots", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let selection = OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        let routine = try unwrap(OnboardingRoutineFactory.routines(from: selection).first, "Stretch routine")
        let slots = ScheduleEngine(calendar: calendar).slots(for: routine, on: day)
        try expectEqual(slots.map { calendar.component(.hour, from: $0.scheduledAt) }, [11, 15], "Stretch slot hours")
        try expectEqual(slots.map { calendar.component(.minute, from: $0.scheduledAt) }, [0, 30], "Stretch slot minutes")
    }),
    ("confirming onboarding persists selected routines and marks completed", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let selection = OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)

        store.confirmOnboarding(selection)

        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.onboardingStatus, .completed, "onboarding completed")
        try expectEqual(reloaded.routines.map(\.title), ["Stretch"], "confirmed routine persisted")
    }),
    ("dismissing onboarding before confirm leaves no active routines", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        store.markOnboardingDismissedBeforeConfirm()

        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.onboardingStatus, .dismissedBeforeConfirm, "dismissed state")
        try expectEqual(reloaded.routines, [], "dismiss should not activate routines")
        try expect(ScheduleEngine(calendar: makeCalendar()).nextRuntimeTrigger(for: reloaded.routines, after: Date()) == nil, "nothing should schedule")
    }),
    ("confirming zero selected routines keeps setup incomplete with empty routines", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        store.confirmOnboarding(OnboardingSelection(selectedTemplateKeys: [], customDraft: nil))

        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.onboardingStatus, .dismissedBeforeConfirm, "zero selection should keep setup incomplete until a routine exists")
        try expectEqual(reloaded.routines, [], "zero selection keeps empty routines")
    }),
    ("dismiss-before-confirm cannot downgrade completed onboarding", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        store.confirmOnboarding(OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil))

        store.markOnboardingDismissedBeforeConfirm()

        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.onboardingStatus, .completed, "completed onboarding should not be downgraded by a later empty onboarding route")
        try expectEqual(OnboardingActivation.runtimeRoutines(from: reloaded).count, 1, "completed routines should remain schedulable")
    }),
    ("runtime activation returns no routines before completed onboarding", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        store.markOnboardingDismissedBeforeConfirm()
        store.saveRoutines([Routine.defaultRoutines()[0]])

        try expectEqual(OnboardingActivation.runtimeRoutines(from: store), [], "not completed should not schedule")

        store.markOnboardingCompleted()
        try expectEqual(OnboardingActivation.runtimeRoutines(from: store).count, 1, "completed should schedule saved routines")
    }),
    ("onboarding launch policy only auto opens first untouched setup", {
        try expect(OnboardingLaunchPolicy.shouldAutoOpenSetup(status: .notStarted), "fresh setup should auto open")
        try expect(!OnboardingLaunchPolicy.shouldAutoOpenSetup(status: .dismissedBeforeConfirm), "dismissed setup should wait for menu reopen")
        try expect(!OnboardingLaunchPolicy.shouldAutoOpenSetup(status: .completed), "completed setup should not auto open")
    }),
    ("settings schedule normalization preserves exact onboarding slots until advanced changes", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        let routine = OnboardingRoutineFactory.routines(
            from: OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        )[0]

        let normalized = RoutineSettingsNormalizer.normalized(routine)
        let slots = ScheduleEngine(calendar: calendar).slots(for: normalized, on: day)

        try expectEqual(normalized.exactDailyTimes, [DailyTime(hour: 11, minute: 0), DailyTime(hour: 15, minute: 30)], "exact onboarding times stay intact")
        try expectEqual(slots.map { calendar.component(.hour, from: $0.scheduledAt) }, [11, 15], "exact slot hours stay intact")
        try expectEqual(slots.map { calendar.component(.minute, from: $0.scheduledAt) }, [0, 30], "exact slot minutes stay intact")
    }),
    ("settings schedule normalization clears exact slots after advanced schedule edits", {
        let calendar = makeCalendar()
        let day = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 0, minute: 0)
        var routine = OnboardingRoutineFactory.routines(
            from: OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        )[0]
        routine.windows = [RoutineWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 12, minute: 0))]
        routine.frequency = RoutineFrequency(runsPerDay: 1, minimumGapMinutes: 0, distribution: .evenlySpread)

        let normalized = RoutineSettingsNormalizer.normalized(routine)
        let slots = ScheduleEngine(calendar: calendar).slots(for: normalized, on: day)

        try expectEqual(normalized.exactDailyTimes, nil, "edited advanced schedule should stop using stale exact onboarding times")
        try expectEqual(slots.map { calendar.component(.hour, from: $0.scheduledAt) }, [10], "edited window drives slot hour")
        try expectEqual(slots.map { calendar.component(.minute, from: $0.scheduledAt) }, [30], "edited window drives slot minute")
    }),
    ("settings schedule normalization keeps exact slots valid when only frequency fields drift", {
        var routine = OnboardingRoutineFactory.routines(
            from: OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        )[0]
        routine.frequency = RoutineFrequency(runsPerDay: 3, minimumGapMinutes: 30, distribution: .random)

        let normalized = RoutineSettingsNormalizer.normalized(routine)

        try expectEqual(normalized.exactDailyTimes, [DailyTime(hour: 11, minute: 0), DailyTime(hour: 15, minute: 30)], "exact times should stay authoritative")
        try expectEqual(normalized.frequency.runsPerDay, 2, "frequency count should follow exact slots")
        try expectEqual(normalized.frequency.minimumGapMinutes, 0, "exact slots should not inherit stale gap")
        try expectEqual(normalized.frequency.distribution, .evenlySpread, "exact slots should not inherit stale distribution")
        try expectEqual(RoutineValidator.validationIssue(for: normalized), nil, "normalized exact routine should remain valid")
    }),
    ("runtime scheduler uses onboarding activation gate", {
        let text = try sourceText("Sources/PauseApp/RuntimeScheduler.swift")
        try expect(text.contains("OnboardingActivation.runtimeRoutines"), "RuntimeScheduler should use onboarding activation helper")
    }),
    ("today preview uses selected templates and schedule engine semantics", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 9, minute: 0)
        let selection = OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        let preview = OnboardingPreviewService(calendar: calendar).previewToday(selection: selection, after: now)

        try expectEqual(preview.map(\.routineTitle), ["Stretch", "Stretch"], "preview titles")
        try expectEqual(preview.map { calendar.component(.hour, from: $0.date) }, [11, 15], "preview hours")
        try expectEqual(preview.map { calendar.component(.minute, from: $0.date) }, [0, 30], "preview minutes")
    }),
    ("today preview returns empty state for zero selected routines", {
        let preview = OnboardingPreviewService(calendar: makeCalendar()).previewToday(
            selection: OnboardingSelection(selectedTemplateKeys: [], customDraft: nil),
            after: Date()
        )
        try expectEqual(preview, [], "zero selection has no preview items")
    }),
    ("onboarding selection knows when settings should be the next step", {
        let empty = OnboardingSelection(selectedTemplateKeys: [], customDraft: nil)
        let templateOnly = OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        let customOnly = OnboardingSelection(
            selectedTemplateKeys: [],
            customDraft: CustomRoutineDraft(name: "Walk outside", glyphSymbolName: "figure.walk", dailyTime: DailyTime(hour: 15, minute: 10), dailyCount: 1)
        )

        try expect(!empty.hasAnyRoutine, "empty selection should route to settings instead of confirming an invisible start")
        try expect(templateOnly.hasAnyRoutine, "selected templates should allow normal confirmation")
        try expect(customOnly.hasAnyRoutine, "enabled custom draft should allow normal confirmation")
    }),
    ("today preview excludes already-passed slots", {
        let calendar = makeCalendar()
        let now = makeDate(calendar, year: 2026, month: 5, day: 6, hour: 12, minute: 0)
        let selection = OnboardingSelection(selectedTemplateKeys: [.stretch], customDraft: nil)
        let preview = OnboardingPreviewService(calendar: calendar).previewToday(selection: selection, after: now)

        try expectEqual(preview.count, 1, "only afternoon stretch remains")
        try expectEqual(calendar.component(.hour, from: preview[0].date), 15, "remaining preview hour")
        try expectEqual(calendar.component(.minute, from: preview[0].date), 30, "remaining preview minute")
    }),
    ("custom routine draft exposes only minimal onboarding fields", {
        let draft = CustomRoutineDraft(
            name: "Walk outside",
            glyphSymbolName: "figure.walk",
            dailyTime: DailyTime(hour: 16, minute: 0),
            dailyCount: 1
        )
        try expectEqual(draft.name, "Walk outside", "custom name")
        try expectEqual(draft.glyphSymbolName, "figure.walk", "custom glyph")
        try expectEqual(draft.dailyTime, DailyTime(hour: 16, minute: 0), "custom time")
        try expectEqual(draft.dailyCount, 1, "custom count")
    }),
    ("routine can persist an optional custom glyph", {
        let routine = Routine(
            title: "Walk outside",
            actionType: .exercise,
            schedule: .fixedTime(DailyTime(hour: 16, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            glyphSymbolName: "figure.walk"
        )
        let data = try JSONEncoder().encode(routine)
        let decoded = try JSONDecoder().decode(Routine.self, from: data)
        try expectEqual(decoded.glyphSymbolName, "figure.walk", "glyph persists")

        let legacy = Routine(
            title: "Stretch",
            actionType: .stretch,
            schedule: .fixedTime(DailyTime(hour: 11, minute: 0)),
            countdownSeconds: 90,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30)
        )
        let legacyDecoded = try JSONDecoder().decode(Routine.self, from: JSONEncoder().encode(legacy))
        try expectEqual(legacyDecoded.glyphSymbolName, nil, "missing glyph stays nil")
    }),
    ("custom draft converts to a routine with glyph time and count", {
        let draft = CustomRoutineDraft(name: "Walk outside", glyphSymbolName: "figure.walk", dailyTime: DailyTime(hour: 16, minute: 0), dailyCount: 2)
        let selection = OnboardingSelection(selectedTemplateKeys: [], customDraft: draft)
        let routines = OnboardingRoutineFactory.routines(from: selection)

        let routine = try unwrap(routines.first, "custom routine")
        try expectEqual(routine.title, "Walk outside", "custom title")
        try expectEqual(routine.actionType, .exercise, "custom action fallback")
        try expectEqual(routine.glyphSymbolName, "figure.walk", "custom glyph")
        try expectEqual(routine.frequency.runsPerDay, 2, "custom count")
    }),
    ("localization exposes benefit-first onboarding copy", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)
        try expectEqual(english.onboardingTitle, "Set up your first puz", "English onboarding title")
        try expectEqual(korean.onboardingTitle, "첫 puz를 설정해요", "Korean onboarding title")
        try expectEqual(english.onboardingWelcomeTitle, "Build a healthier break habit", "English welcome benefit title")
        try expectEqual(korean.onboardingWelcomeTitle, "건강한 휴식 습관을 만들어요", "Korean welcome benefit title")
        try expectEqual(korean.onboardingWelcomeBenefit, "과도한 몰입에서 잠시 벗어나 몸과 마음의 재충전을 도와요.", "Korean welcome benefit copy")
        try expectEqual(korean.onboardingWelcomeMenuBar, "평소에는 메뉴바에 있고, 지정한 규칙에 따라 전체 화면으로 등장해요.", "Korean menu bar copy")
        try expectEqual(korean.onboardingWelcomeSnooze, "1분, 30분 미루기로 업무 상황에 맞게 조절할 수 있어요.", "Korean snooze copy")
        try expectEqual(korean.onboardingWelcomeResume, "카운트다운이 끝나면 Resume으로 돌아와 fresh하게 다시 집중하세요.", "Korean resume copy")
        try expectEqual(korean.onboardingContinueButtonTitle, "계속하기", "Korean continue CTA")
        try expectEqual(english.onboardingTemplateTitle(.eyeRest), "Eye rest", "English eye-rest card")
        try expectEqual(korean.onboardingTemplateIntent(.stretch), "어깨, 목, 고관절을 짧게 풀어요.", "Korean stretch intent")
        try expectEqual(english.todayPreviewHeading, "Today preview", "English preview heading")
        try expectEqual(english.glyphLabel, "Icon", "English custom glyph label")
        try expectEqual(korean.glyphLabel, "아이콘", "Korean custom glyph label")
        try expectEqual(english.onboardingOpenSettingsButtonTitle, "Open settings", "English zero-selection CTA")
        try expectEqual(korean.onboardingOpenSettingsButtonTitle, "설정으로 가기", "Korean zero-selection CTA")
        try expectEqual(english.onboardingNoSelectionPreview, "No puz selected yet", "English no-selection preview")
        try expectEqual(korean.onboardingNoSelectionPreview, "아직 선택한 puz가 없어요", "Korean no-selection preview")
    }),
    ("prompt copy makes snooze close and resume meanings explicit", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)
        try expectEqual(english.promptHelper, "Start begins the fullscreen countdown. Snooze asks again later. Resume appears after the timer.", "English prompt helper semantics")
        try expectEqual(korean.promptHelper, "시작하면 전체 화면 카운트다운이 진행돼요. 미루기는 나중에 다시 묻고, Resume은 타이머 후에 나타나요.", "Korean prompt helper semantics")
        try expectEqual(english.snoozeButtonTitle(.oneMinute), "Snooze 1 min", "English one-minute snooze title")
        try expectEqual(english.snoozeButtonTitle(.thirtyMinutes), "Snooze 30 min", "English thirty-minute snooze title")
        try expectEqual(english.snoozeButtonTitle(.random), "Random snooze", "English random snooze title")
        try expectEqual(korean.snoozeButtonTitle(.oneMinute), "1분 미루기", "Korean one-minute snooze title")
        try expectEqual(korean.snoozeButtonTitle(.thirtyMinutes), "30분 미루기", "Korean thirty-minute snooze title")
        try expectEqual(korean.snoozeButtonTitle(.random), "랜덤 미루기", "Korean random snooze title")
        try expectEqual(english.endSessionActionTitle(.justClose), "Close only", "English close-only title")
        try expectEqual(korean.endSessionActionTitle(.justClose), "닫기만", "Korean close-only title")
    }),
    ("onboarding starts with a welcome step before routine selection", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("enum OnboardingStep"), "onboarding should model a welcome-first step")
        try expect(text.contains("@State private var step = OnboardingStep.welcome"), "onboarding should open on the welcome step")
        try expect(text.contains("welcomeStep"), "onboarding should render the welcome step")
        try expect(text.contains("routineSelectionStep"), "routine selection should be a later step")
    }),
    ("onboarding and menu copy avoid notification language", {
        let text = try sourceText("Sources/PauseCore/PuzLocalization.swift")
        try expect(!text.localizedCaseInsensitiveContains("notification"), "localization should not promise notifications")
        try expect(!text.contains("알림 일정"), "Korean copy should avoid notification-schedule framing")
    }),
    ("menu exposes setup action copy", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)
        try expectEqual(english.finishSetupLabel, "Finish setup", "English setup CTA")
        try expectEqual(korean.finishSetupLabel, "설정 마치기", "Korean setup CTA")
    }),
    ("menu copy distinguishes setup incomplete from no active routines", {
        let english = PuzLocalization(language: .english)
        try expectEqual(english.menuSetupIncomplete, "Setup incomplete", "setup incomplete menu state")
        try expectEqual(english.menuNoRoutines, "No routines", "completed-empty no routines state")
    }),
    ("localization exposes advanced settings copy", {
        let english = PuzLocalization(language: .english)
        let korean = PuzLocalization(language: .korean)
        try expectEqual(english.advancedSettingsTitle, "Advanced schedule", "English advanced title")
        try expectEqual(korean.advancedSettingsTitle, "고급 일정", "Korean advanced title")
    }),
    ("app has onboarding window controller source", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("final class OnboardingWindowController"), "onboarding controller should exist")
    }),
    ("app delegate gates initial scheduling on onboarding", {
        let text = try sourceText("Sources/PauseApp/AppDelegate.swift")
        try expect(text.contains("hasCompletedOnboarding"), "AppDelegate should check onboarding completion")
        try expect(text.contains("OnboardingWindowController"), "AppDelegate should own onboarding controller")
    }),
    ("onboarding view renders recommended templates", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("RecommendedPuzTemplate.defaults"), "onboarding view should use template defaults")
        try expect(text.contains("Toggle") || text.contains("toggle"), "onboarding cards should toggle selection")
    }),
    ("onboarding view uses preview service", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("OnboardingPreviewService"), "onboarding view should use preview service")
        try expect(text.contains("onboardingNoSelectionPreview"), "onboarding view should show empty preview copy")
    }),
    ("onboarding custom UI stays minimal", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("CustomRoutineDraft"), "onboarding should use custom draft")
        try expect(text.contains("TimeStepper(hour: $customHour, minute: $customMinute)"), "custom onboarding time should use one compact HH:mm editor")
        try expect(!text.contains("Stepper(value: $customMinute") && !text.contains("Text(strings.minuteUnit)"), "custom onboarding should not render a detached minute-only stepper")
        try expect(!text.contains("minimumGap"), "onboarding should not expose minimum gap")
        try expect(!text.contains("DistributionMode"), "onboarding should not expose distribution")
    }),
    ("onboarding custom glyph picker exposes many icon choices", {
        let choices = OnboardingGlyphChoice.defaults
        try expect(choices.count >= 24, "custom glyph picker should feel like a page icon chooser, not five actions")
        try expectEqual(choices.first?.symbolName, "figure.walk", "walking remains the default glyph")
        try expect(choices.contains { $0.symbolName == "leaf" }, "wellness glyphs should be included")
        try expect(choices.contains { $0.symbolName == "timer" }, "utility glyphs should be included")
        try expectEqual(Set(choices.map(\.symbolName)).count, choices.count, "glyph symbols should be unique")
    }),
    ("onboarding zero-selection primary action opens settings instead of pretending to start", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("onOpenSettings"), "onboarding should have a settings route")
        try expect(text.contains("selection.hasAnyRoutine"), "primary CTA should branch on empty selection")
        try expect(text.contains("onboardingOpenSettingsButtonTitle"), "empty selection should use settings CTA copy")
        try expect(text.contains("markOnboardingDismissedBeforeConfirm"), "empty settings route should not complete onboarding before a routine is saved")
    }),
    ("onboarding layout keeps the footer out of the scrolling body", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("OnboardingWindowMetrics"), "onboarding should use named window metrics instead of scattered fixed sizes")
        try expect(text.contains("footer"), "onboarding should keep footer as a named persistent area")
        try expect(text.contains(".frame(maxWidth: .infinity, maxHeight: .infinity") || text.contains(".frame(maxHeight: .infinity"), "routine content should get a real scrollable viewport")
        try expect(!text.contains(".frame(width: 760, height: 640)"), "onboarding should not keep the old clipped fixed frame")
    }),
    ("onboarding confirm calls confirmOnboarding", {
        let text = try sourceText("Sources/PauseApp/OnboardingWindowController.swift")
        try expect(text.contains("confirmOnboarding"), "confirm button should persist through RoutineStore.confirmOnboarding")
    }),
    ("qa launch flags can open deterministic windows without AX menu clicks", {
        let launchText = try sourceText("Sources/PauseCore/PuzLaunchOptions.swift")
        let mainText = try sourceText("Sources/PauseApp/main.swift")
        let appDelegateText = try sourceText("Sources/PauseApp/AppDelegate.swift")
        try expect(launchText.contains("--qa-open-onboarding"), "QA launch options should support opening onboarding")
        try expect(launchText.contains("--qa-open-settings"), "QA launch options should support opening settings")
        try expect(launchText.contains("--qa-reset"), "QA launch options should support a fresh defaults reset")
        try expect(mainText.contains("PuzLaunchOptions.current"), "main should parse launch options before the app delegate starts")
        try expect(appDelegateText.contains("launchOptions"), "AppDelegate should receive launch options")
    }),
    ("qa launch reset requires explicit confirmation", {
        let unconfirmed = PuzLaunchOptions(arguments: ["puz", "--qa-reset"], environment: [:])
        let confirmed = PuzLaunchOptions(arguments: ["puz", "--qa-reset"], environment: [PuzLaunchOptions.qaResetConfirmationEnvironmentKey: "1"])

        try expect(unconfirmed.qaResetRequested, "reset flag should be visible for diagnostics")
        try expect(!unconfirmed.qaResetDefaults, "reset should not run without explicit environment confirmation")
        try expect(confirmed.qaResetDefaults, "reset should run with explicit environment confirmation")
    }),
    ("qa launch window request precedence is deterministic", {
        let both = PuzLaunchOptions(arguments: ["puz", "--qa-open-settings", "--qa-open-onboarding"], environment: [:])
        try expect(both.qaOpenOnboarding, "onboarding should win when both QA window flags are supplied")
        try expect(!both.qaOpenSettings, "settings should not also open when onboarding wins precedence")
    }),
    ("qa reset reports when bundle reset cannot happen", {
        let options = PuzLaunchOptions(arguments: ["puz", "--qa-reset"], environment: [PuzLaunchOptions.qaResetConfirmationEnvironmentKey: "1"])
        let reset = options.resetStandardDefaultsIfRequested(bundleIdentifier: nil, defaults: makeDefaults())
        try expect(!reset, "reset should report false when no bundle identifier is available")
    }),
    ("settings save can complete setup once a routine exists", {
        let appDelegateText = try sourceText("Sources/PauseApp/AppDelegate.swift")
        try expect(appDelegateText.contains("settingsWindowController.onSave = { [weak self] in\n            self?.completeOnboardingAfterSettingsSave()"), "settings save should complete incomplete onboarding after a non-empty routine save")
        try expect(appDelegateText.contains("markOnboardingCompleted()"), "settings completion path should mark onboarding completed")
    }),
    ("settings empty state has one primary empty-state title and one CTA", {
        let text = try sourceText("Sources/PauseApp/SettingsWindowController.swift")
        let emptyTitleCount = text.components(separatedBy: "Text(strings.noRoutinesTitle)").count - 1
        try expectEqual(emptyTitleCount, 1, "settings should not repeat the same empty-state title in sidebar and detail")
        try expect(text.contains("emptyRoutineDetail"), "settings should render a single detail empty state with CTA")
    }),
    ("menu bar supports reopening incomplete setup", {
        let text = try sourceText("Sources/PauseApp/MenuBarController.swift")
        try expect(text.contains("onOpenOnboarding"), "menu should expose onboarding callback")
        try expect(text.contains("finishSetupLabel"), "menu should render setup CTA copy")
        try expect(text.contains("onboardingStatus"), "menu update should know onboarding status")
    }),
    ("settings uses icon picker instead of action picker in basics", {
        let settingsText = try sourceText("Sources/PauseApp/SettingsWindowController.swift")
        let promptText = try sourceText("Sources/PauseApp/PromptController.swift")
        let overlayText = try sourceText("Sources/PauseApp/OverlayController.swift")
        try expect(settingsText.contains("Picker(strings.glyphLabel"), "settings basics should label the chooser as Icon")
        try expect(settingsText.contains("OnboardingGlyphChoice.defaults"), "settings icon picker should reuse the onboarding icon choices")
        try expect(!settingsText.contains("Picker(strings.actionLabel"), "settings basics should not expose Action copy")
        try expect(promptText.contains("symbolName: routine.glyphSymbolName"), "prompt should render the chosen routine icon")
        try expect(overlayText.contains("symbolName: routine.glyphSymbolName"), "fullscreen overlay should render the chosen routine icon")
    }),
    ("fullscreen flow supports enter and arrow keyboard use", {
        let promptText = try sourceText("Sources/PauseApp/PromptController.swift")
        let overlayText = try sourceText("Sources/PauseApp/OverlayController.swift")
        let stylesText = try sourceText("Sources/PauseApp/PuzStyles.swift")
        try expect(stylesText.contains("case 36, 76"), "return and keypad enter should be handled")
        try expect(stylesText.contains("case 124, 125") && stylesText.contains("case 123, 126"), "arrow keys should be handled")
        try expect(promptText.contains("selectedKeyboardTarget") && promptText.contains("SnoozeDelayOption.promptOptions.map(PromptKeyboardTarget.snooze)"), "prompt should allow arrow selection across start and snooze")
        try expect(overlayText.contains("handleKeyboardCommand") && overlayText.contains("session.resume()"), "completed countdown should support Enter to resume")
        try expect(stylesText.contains("PuzEndSessionDialogTarget") && stylesText.contains("isKeyboardFocused"), "end-session dialog should expose keyboard-focused actions")
    }),
    ("fullscreen close dialog uses opaque surface", {
        let stylesText = try sourceText("Sources/PauseApp/PuzStyles.swift")
        try expect(stylesText.contains("dialogSurface"), "dialog should use a named solid surface color")
        try expect(stylesText.contains(".fill(PuzFullscreenTheme.dialogSurface)"), "dialog card should be opaque so rear buttons do not bleed through")
        try expect(!stylesText.contains("Color.white.opacity(0.94)"), "dialog card should not remain translucent")
    }),
    ("settings hides schedule power behind advanced disclosure", {
        let text = try sourceText("Sources/PauseApp/SettingsWindowController.swift")
        try expect(text.contains("advancedSettingsTitle"), "settings should render advanced settings title")
        try expect(text.contains("DisclosureGroup") || text.contains("isAdvanced"), "settings should use an explicit advanced disclosure/state")
    }),
    ("routine validation rejects impossible frequency", {
        let routine = Routine(
            title: "Too frequent",
            actionType: .stretch,
            schedule: .randomWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 10, minute: 0)),
            countdownSeconds: 60,
            snoozePolicy: SnoozePolicy(maxCount: 2, intervalMinutes: 30),
            activeWeekdays: [.wednesday],
            windows: [RoutineWindow(start: DailyTime(hour: 9, minute: 0), end: DailyTime(hour: 10, minute: 0))],
            frequency: RoutineFrequency(runsPerDay: 4, minimumGapMinutes: 30, distribution: .evenlySpread)
        )
        try expectEqual(RoutineValidator.validationIssue(for: routine), .impossibleFrequency, "impossible frequency rejected")
    }),
    ("fresh store starts with onboarding not completed", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        try expectEqual(store.onboardingStatus, .notStarted, "fresh onboarding status")
        try expect(!store.hasCompletedOnboarding, "fresh store should not be onboarded")
    }),
    ("persisted routines without onboarding status are treated as onboarded", {
        let defaults = makeDefaults()
        let existing = Routine.defaultRoutines()
        let data = try JSONEncoder().encode(existing)
        defaults.set(data, forKey: "pause.routines")
        defaults.set(2, forKey: "pause.storeVersion")

        let store = RoutineStore(defaults: defaults)
        try expectEqual(store.onboardingStatus, .completed, "existing routines imply completed onboarding")
        try expect(store.hasCompletedOnboarding, "existing routines should keep scheduling")
        try expectEqual(store.routines.map(\.title), existing.map(\.title), "existing routines preserved")
    }),
    ("onboarding status persists across store instances", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        store.markOnboardingDismissedBeforeConfirm()
        try expectEqual(RoutineStore(defaults: defaults).onboardingStatus, .dismissedBeforeConfirm, "dismissed state persists")

        store.markOnboardingCompleted()
        try expectEqual(RoutineStore(defaults: defaults).onboardingStatus, .completed, "completed state persists")
    }),
    ("fresh store has no active routines before onboarding confirmation", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        try expectEqual(store.routines, [], "fresh routines should not bootstrap active defaults")
        try expectEqual(store.onboardingStatus, .notStarted, "fresh store should still need onboarding")
    }),
    ("legacy stored routine data resets to v2 defaults", {
        let defaults = makeDefaults()
        defaults.set(Data("[{\"legacy\":true}]".utf8), forKey: "pause.routines")
        defaults.set(1, forKey: "pause.storeVersion")
        let store = RoutineStore(defaults: defaults)
        try expectEqual(store.routines.map(\.title), ["Stretch", "Hydrate", "Stand up"], "legacy routines reset to v2 defaults")
    }),
    ("empty routine list can persist across store instances", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        store.saveRoutines([])
        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.routines, [], "empty routines should remain empty")
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
    ("store saves one routine without dropping siblings", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        var first = Routine.defaultBurpee()
        first = Routine(
            id: firstID,
            title: "Stretch",
            actionType: .stretch,
            schedule: first.schedule,
            countdownSeconds: first.countdownSeconds,
            snoozePolicy: first.snoozePolicy
        )
        let second = Routine(
            id: secondID,
            title: "Hydrate",
            actionType: .drinkWater,
            schedule: first.schedule,
            countdownSeconds: 60,
            snoozePolicy: first.snoozePolicy
        )
        store.replaceRoutines([first, second])
        first.title = "Stretch updated"
        store.saveRoutine(first)
        try expectEqual(store.routines.map(\.title), ["Stretch updated", "Hydrate"], "saveRoutine should preserve siblings")
    }),
    ("store deletes routines and allows empty lists", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let first = Routine.defaultBurpee()
        let second = Routine.defaultRoutines()[1]
        store.replaceRoutines([first, second])
        store.deleteRoutine(id: first.id)
        try expectEqual(store.routines.map(\.id), [second.id], "delete should remove only matching routine")
        store.deleteRoutine(id: second.id)
        try expectEqual(store.routines, [], "deleting last routine should leave empty list")
    }),
    ("store duplicates routines with a new identity", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let original = Routine.defaultRoutines()[1]
        store.replaceRoutines([original])
        let duplicate = try unwrap(store.duplicateRoutine(id: original.id), "duplicate should be returned")
        try expect(duplicate.id != original.id, "duplicate id should be new")
        try expectEqual(duplicate.title, "Hydrate copy", "duplicate title")
        try expectEqual(store.routines.map(\.title), ["Hydrate", "Hydrate copy"], "duplicate should be appended")
    }),
    ("store toggles a routine enabled state", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let routine = Routine.defaultRoutines()[0]
        store.replaceRoutines([routine])
        store.setRoutineEnabled(id: routine.id, isEnabled: false)
        try expectEqual(store.routines.first?.isEnabled, false, "routine should be disabled")
        store.setRoutineEnabled(id: routine.id, isEnabled: true)
        try expectEqual(store.routines.first?.isEnabled, true, "routine should be enabled")
    }),
    ("completion records persist slot metadata across store instances", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let routineID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_800_000_000)
        let record = CompletionRecord(
            routineID: routineID,
            completedAt: Date(timeIntervalSince1970: 1_800_000_060),
            snoozeCount: 2,
            wasInterrupted: false,
            scheduledAt: scheduledAt,
            slotKey: "slot-1"
        )
        store.appendCompletionRecord(record)
        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.completionRecords, [record], "persisted completion records")
        try expectEqual(reloaded.completionRecords.first?.scheduledAt, scheduledAt, "completion scheduledAt")
        try expectEqual(reloaded.completionRecords.first?.slotKey, "slot-1", "completion slotKey")
    }),
    ("skip records persist slot metadata separately from completion records", {
        let defaults = makeDefaults()
        let store = RoutineStore(defaults: defaults)
        let routineID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_800_000_000)
        let skip = SkipRecord(
            routineID: routineID,
            scheduledDate: scheduledAt,
            skippedAt: Date(timeIntervalSince1970: 1_800_000_060),
            scheduledAt: scheduledAt,
            slotKey: "slot-1"
        )
        store.appendSkipRecord(skip)
        let reloaded = RoutineStore(defaults: defaults)
        try expectEqual(reloaded.skipRecords, [skip], "persisted skip records")
        try expectEqual(reloaded.skipRecords.first?.scheduledAt, scheduledAt, "skip scheduledAt")
        try expectEqual(reloaded.skipRecords.first?.slotKey, "slot-1", "skip slotKey")
        try expectEqual(reloaded.completionRecords, [], "skip should not create completion records")
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
