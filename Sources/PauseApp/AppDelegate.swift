import AppKit
import UserNotifications
import PauseCore

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let store = RoutineStore()
    private var menuBarController: MenuBarController!
    private var promptController: PromptController!
    private var overlayController: OverlayController!
    private var settingsWindowController: SettingsWindowController!
    private var runtimeScheduler: RuntimeScheduler!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()

        promptController = PromptController()
        overlayController = OverlayController()
        menuBarController = MenuBarController()
        settingsWindowController = SettingsWindowController(store: store)

        runtimeScheduler = RuntimeScheduler(
            store: store,
            promptController: promptController,
            overlayController: overlayController,
            menuBarController: menuBarController
        )

        menuBarController.onStartNow = { [weak self] in
            self?.runtimeScheduler.startNow()
        }
        menuBarController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }
        settingsWindowController.onSave = { [weak self] in
            self?.runtimeScheduler.reloadAndSchedule()
        }

        runtimeScheduler.reloadAndSchedule()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtimeScheduler?.stop()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("puz notification permission error: \(error.localizedDescription)")
            }
            if !granted {
                NSLog("puz notification permission denied; in-app prompt will still appear.")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
