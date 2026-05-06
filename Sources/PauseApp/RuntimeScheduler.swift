import Foundation
import AppKit
import UserNotifications
import PauseCore

final class RuntimeScheduler {
    private let store: RoutineStore
    private let promptController: PromptController
    private let overlayController: OverlayController
    private let menuBarController: MenuBarController
    private let scheduleEngine = ScheduleEngine()

    private var timer: Timer?
    private var activeRoutine: Routine?
    private var activeSnoozeCount = 0
    private var activeTriggerDate: Date?
    private var notificationID: String?

    init(
        store: RoutineStore,
        promptController: PromptController,
        overlayController: OverlayController,
        menuBarController: MenuBarController
    ) {
        self.store = store
        self.promptController = promptController
        self.overlayController = overlayController
        self.menuBarController = menuBarController
    }

    func reloadAndSchedule() {
        timer?.invalidate()
        timer = nil
        promptController.dismiss()
        scheduleNextRoutine()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancelPendingNotification()
    }

    func startNow() {
        let routine = store.routines.first(where: { $0.isEnabled }) ?? Routine.defaultBurpee()
        activeRoutine = routine
        activeSnoozeCount = 0
        activeTriggerDate = Date()
        startCountdown(for: routine)
    }

    private func scheduleNextRoutine() {
        cancelPendingNotification()

        let now = Date()
        guard let next = scheduleEngine.nextRuntimeTrigger(
            for: store.routines,
            completionRecords: store.completionRecords,
            after: now
        ) else {
            activeRoutine = nil
            activeSnoozeCount = 0
            activeTriggerDate = nil
            updateMenu(nextDate: nil)
            return
        }

        activeRoutine = next.routine
        activeSnoozeCount = 0
        activeTriggerDate = next.date
        scheduleTimer(for: next.routine, at: next.date)
        scheduleNotification(for: next.routine, at: next.date)
        updateMenu(nextDate: next.date)
    }

    private func scheduleTimer(for routine: Routine, at date: Date) {
        timer?.invalidate()
        let interval = max(1, date.timeIntervalSinceNow)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.presentPrompt(for: routine)
        }
    }

    private func presentPrompt(for routine: Routine) {
        promptController.show(
            routine: routine,
            scheduledDate: activeTriggerDate ?? Date(),
            usedSnoozeCount: activeSnoozeCount,
            onStart: { [weak self] in
                self?.startCountdown(for: routine)
            },
            onSnooze: { [weak self] option in
                self?.snooze(routine, option: option)
            },
            onCancel: { [weak self] in
                self?.cancelActiveFullscreenFlow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    private func snooze(_ routine: Routine, option: SnoozeDelayOption) {
        let state = SnoozePromptState(policy: routine.snoozePolicy, usedCount: activeSnoozeCount)
        guard state.canSnooze else { return }

        let delaySeconds = option.delaySeconds()
        let nextDate = Date().addingTimeInterval(TimeInterval(delaySeconds))
        activeSnoozeCount += 1
        activeTriggerDate = nextDate
        promptController.dismiss()
        scheduleTimer(for: routine, at: nextDate)
        scheduleNotification(for: routine, at: nextDate)
        updateMenu(nextDate: nextDate)
    }

    private func startCountdown(for routine: Routine) {
        timer?.invalidate()
        timer = nil
        cancelPendingNotification()
        promptController.dismiss()
        let usedSnoozeCount = activeSnoozeCount

        overlayController.startCountdown(
            routine: routine,
            onComplete: { [weak self] in
                guard let self else { return }
                self.store.appendCompletionRecord(
                    CompletionRecord(
                        routineID: routine.id,
                        completedAt: Date(),
                        snoozeCount: usedSnoozeCount,
                        wasInterrupted: false
                    )
                )
                self.activeRoutine = nil
                self.activeSnoozeCount = 0
                self.activeTriggerDate = nil
                self.scheduleNextRoutine()
            },
            onCancel: { [weak self] in
                self?.cancelActiveFullscreenFlow()
            }
        )
    }

    private func cancelActiveFullscreenFlow() {
        timer?.invalidate()
        timer = nil
        cancelPendingNotification()
        promptController.dismiss()
        activeRoutine = nil
        activeSnoozeCount = 0
        activeTriggerDate = nil
        scheduleNextRoutine()
    }

    private func scheduleNotification(for routine: Routine, at date: Date) {
        cancelPendingNotification()
        let interval = max(1, date.timeIntervalSinceNow)
        let content = UNMutableNotificationContent()
        content.title = "\(routine.title) 시간"
        content.body = "지금 시작하거나 1분/30분/랜덤으로 미룰 수 있어요."
        content.sound = .default

        let id = "puz.\(routine.id.uuidString).\(Int(date.timeIntervalSince1970))"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        notificationID = id
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("puz notification scheduling error: \(error.localizedDescription)")
            }
        }
    }

    private func cancelPendingNotification() {
        guard let notificationID else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
        self.notificationID = nil
    }

    private func updateMenu(nextDate: Date?) {
        menuBarController.update(
            nextDate: nextDate,
            todayCount: store.completions(on: Date()).filter { !$0.wasInterrupted }.count
        )
    }
}
