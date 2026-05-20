import AppKit
import PauseCore

final class MenuBarController: NSObject {
    var onStartNow: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenOnboarding: (() -> Void)?
    var onQuit: (() -> Void)?

    private let strings: PuzLocalization
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let nextItem: NSMenuItem
    private let todayItem: NSMenuItem
    private let setupItem: NSMenuItem
    private let formatter: DateFormatter

    init(strings: PuzLocalization = .current) {
        self.strings = strings
        self.nextItem = NSMenuItem(title: strings.menuNextCalculating, action: nil, keyEquivalent: "")
        self.todayItem = NSMenuItem(title: strings.todayCompleted(count: 0), action: nil, keyEquivalent: "")
        self.setupItem = NSMenuItem(title: strings.finishSetupLabel, action: #selector(openOnboarding), keyEquivalent: "")

        let formatter = DateFormatter()
        formatter.locale = strings.locale
        formatter.dateFormat = "M/d HH:mm"
        self.formatter = formatter

        super.init()
        statusItem.button?.title = strings.appMenuTitle
        configureMenu()
    }

    func update(next: ScheduledRoutine?, todayCompleted: Int, todayTotal: Int, hasRoutines: Bool, onboardingStatus: OnboardingStatus = .completed) {
        let setupIncomplete = onboardingStatus != .completed
        setupItem.isHidden = !setupIncomplete

        if setupIncomplete {
            nextItem.title = strings.menuSetupIncomplete
            todayItem.title = strings.todayProgress(completed: 0, total: 0)
        } else if hasRoutines {
            nextItem.title = strings.menuNext(
                routineTitle: next.map { strings.routineTitle($0.routine) },
                dateText: next.map { formatter.string(from: $0.date) }
            )
            todayItem.title = strings.todayProgress(completed: todayCompleted, total: todayTotal)
        } else {
            nextItem.title = strings.menuNoRoutines
            todayItem.title = strings.todayProgress(completed: 0, total: 0)
        }
    }

    func update(nextDate: Date?, todayCount: Int) {
        nextItem.title = strings.menuNext(dateText: nextDate.map { formatter.string(from: $0) })
        todayItem.title = strings.todayCompleted(count: todayCount)
    }

    private func configureMenu() {
        let menu = NSMenu()
        nextItem.isEnabled = false
        todayItem.isEnabled = false
        menu.addItem(nextItem)
        menu.addItem(todayItem)
        menu.addItem(.separator())

        let startItem = NSMenuItem(title: strings.startNow, action: #selector(startNow), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)

        setupItem.target = self
        setupItem.isHidden = true
        menu.addItem(setupItem)

        let settingsItem = NSMenuItem(title: strings.settingsTitle, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: strings.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func startNow() {
        onStartNow?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func openOnboarding() {
        onOpenOnboarding?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
