import AppKit
import PauseCore

let launchOptions = PuzLaunchOptions.current
if launchOptions.qaResetRequested && !launchOptions.qaResetDefaults {
    fputs("puz: --qa-reset ignored; set PUZ_QA_RESET_CONFIRMED=1 to confirm defaults reset.\n", stderr)
} else if launchOptions.qaResetDefaults && !launchOptions.resetStandardDefaultsIfRequested() {
    fputs("puz: --qa-reset ignored; bundle identifier unavailable.\n", stderr)
}

let app = NSApplication.shared
let delegate = AppDelegate(launchOptions: launchOptions)
app.delegate = delegate
app.run()
