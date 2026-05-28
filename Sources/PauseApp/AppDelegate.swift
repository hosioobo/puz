import AppKit
import PauseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchOptions: PuzLaunchOptions
    private let store = RoutineStore()
    private var menuBarController: MenuBarController!
    private var promptController: PromptController!
    private var overlayController: OverlayController!
    private var settingsWindowController: SettingsWindowController!
    private var onboardingWindowController: OnboardingWindowController!
    private var runtimeScheduler: RuntimeScheduler!

    init(launchOptions: PuzLaunchOptions = .current) {
        self.launchOptions = launchOptions
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        promptController = PromptController()
        overlayController = OverlayController()
        menuBarController = MenuBarController()
        settingsWindowController = SettingsWindowController(store: store)
        onboardingWindowController = OnboardingWindowController(store: store)

        runtimeScheduler = RuntimeScheduler(
            store: store,
            promptController: promptController,
            overlayController: overlayController,
            menuBarController: menuBarController
        )

        menuBarController.onStartNow = { [weak self] in
            guard let self else { return }
            if self.store.hasCompletedOnboarding {
                self.runtimeScheduler.startNow()
            } else {
                self.onboardingWindowController.show()
            }
        }
        menuBarController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        menuBarController.onOpenOnboarding = { [weak self] in
            self?.onboardingWindowController.show()
        }
        menuBarController.onQuit = {
            NSApp.terminate(nil)
        }
        settingsWindowController.onSave = { [weak self] in
            self?.completeOnboardingAfterSettingsSave()
        }
        onboardingWindowController.onConfirm = { [weak self] in
            self?.runtimeScheduler.reloadAndSchedule()
        }
        onboardingWindowController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }

        if launchOptions.qaOpenOnboarding {
            if store.hasCompletedOnboarding {
                runtimeScheduler.reloadAndSchedule()
            } else {
                updateMenuForIncompleteSetup()
            }
            onboardingWindowController.show()
            return
        }

        if launchOptions.qaOpenSettings {
            if store.hasCompletedOnboarding {
                runtimeScheduler.reloadAndSchedule()
            } else {
                updateMenuForIncompleteSetup()
            }
            settingsWindowController.show()
            return
        }

        if store.hasCompletedOnboarding {
            runtimeScheduler.reloadAndSchedule()
        } else {
            updateMenuForIncompleteSetup()
            if OnboardingLaunchPolicy.shouldAutoOpenSetup(status: store.onboardingStatus) {
                onboardingWindowController.show()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtimeScheduler?.stop()
    }

    private func updateMenuForIncompleteSetup() {
        menuBarController.update(
            next: nil,
            todayCompleted: 0,
            todayTotal: 0,
            hasRoutines: false,
            onboardingStatus: store.onboardingStatus
        )
    }

    private func completeOnboardingAfterSettingsSave() {
        if !store.hasCompletedOnboarding, !store.routines.isEmpty {
            store.markOnboardingCompleted()
        }

        if store.hasCompletedOnboarding {
            runtimeScheduler.reloadAndSchedule()
        } else {
            updateMenuForIncompleteSetup()
        }
    }
}
