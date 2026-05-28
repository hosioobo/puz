import Foundation

public struct PuzLaunchOptions: Equatable {
    public static let qaResetConfirmationEnvironmentKey = "PUZ_QA_RESET_CONFIRMED"

    public let qaOpenOnboarding: Bool
    public let qaOpenSettings: Bool
    public let qaResetRequested: Bool
    public let qaResetDefaults: Bool

    public static var current: PuzLaunchOptions {
        PuzLaunchOptions(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    public init(arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) {
        let flags = Set(arguments.dropFirst())
        let wantsOnboarding = flags.contains("--qa-open-onboarding")
        let wantsSettings = flags.contains("--qa-open-settings")

        // Deterministic precedence: onboarding wins because it is the earliest setup state.
        qaOpenOnboarding = wantsOnboarding
        qaOpenSettings = !wantsOnboarding && wantsSettings
        qaResetRequested = flags.contains("--qa-reset")
        qaResetDefaults = qaResetRequested && environment[Self.qaResetConfirmationEnvironmentKey] == "1"
    }

    @discardableResult
    public func resetStandardDefaultsIfRequested(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard qaResetDefaults, let bundleIdentifier else { return false }
        defaults.removePersistentDomain(forName: bundleIdentifier)
        defaults.synchronize()
        return true
    }
}
