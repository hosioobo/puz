import AppKit

final class MenuBarController: NSObject {
    var onStartNow: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let nextItem = NSMenuItem(title: "다음: 계산 중", action: nil, keyEquivalent: "")
    private let todayItem = NSMenuItem(title: "오늘 완료: 0", action: nil, keyEquivalent: "")
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()

    override init() {
        super.init()
        statusItem.button?.title = "<//> puz"
        configureMenu()
    }

    func update(nextDate: Date?, todayCount: Int) {
        if let nextDate {
            nextItem.title = "다음: \(formatter.string(from: nextDate))"
        } else {
            nextItem.title = "다음: 없음"
        }
        todayItem.title = "오늘 완료: \(todayCount)"
    }

    private func configureMenu() {
        let menu = NSMenu()
        nextItem.isEnabled = false
        todayItem.isEnabled = false
        menu.addItem(nextItem)
        menu.addItem(todayItem)
        menu.addItem(.separator())

        let startItem = NSMenuItem(title: "지금 시작", action: #selector(startNow), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)

        let settingsItem = NSMenuItem(title: "puz 설정", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
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

    @objc private func quit() {
        onQuit?()
    }
}
