import AppKit
import SwiftUI
import PauseCore

final class OnboardingWindowController: NSObject, NSWindowDelegate {
    var onConfirm: (() -> Void)?

    private let store: RoutineStore
    private let strings = PuzLocalization.current
    private var window: NSWindow?

    init(store: RoutineStore) {
        self.store = store
        super.init()
    }

    func show() {
        let view = OnboardingView(
            store: store,
            onConfirm: { [weak self] in
                self?.window?.orderOut(nil)
                self?.onConfirm?()
            },
            onDismiss: { [weak self] in
                self?.closeAsDismissed()
            }
        )

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = strings.onboardingTitle
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }

        window?.title = strings.onboardingTitle
        window?.contentView = NSHostingView(rootView: view)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAsDismissed() {
        if !store.hasCompletedOnboarding {
            store.markOnboardingDismissedBeforeConfirm()
        }
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if !store.hasCompletedOnboarding {
            store.markOnboardingDismissedBeforeConfirm()
        }
    }
}

private enum OnboardingStep {
    case welcome
    case routineSelection
}

private struct OnboardingView: View {
    let store: RoutineStore
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    private let strings = PuzLocalization.current
    private let templates = RecommendedPuzTemplate.defaults
    private let glyphChoices = ["figure.walk", "leaf", "drop", "eye", "sparkles"]

    @State private var selectedTemplateKeys: Set<RecommendedPuzTemplateKey>
    @State private var customEnabled = false
    @State private var customName = ""
    @State private var customGlyphSymbolName = "figure.walk"
    @State private var customHour = 16
    @State private var customMinute = 0
    @State private var customCount = 1
    @State private var step = OnboardingStep.welcome

    init(store: RoutineStore, onConfirm: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        let preselected = RecommendedPuzTemplate.defaults
            .filter(\.isPreselected)
            .map(\.key)
        _selectedTemplateKeys = State(initialValue: Set(preselected))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                PuzBrandLockup()
                VStack(alignment: .leading, spacing: 6) {
                    Text(step == .welcome ? strings.onboardingWelcomeTitle : strings.onboardingTitle)
                        .font(.largeTitle.bold())
                    Text(step == .welcome ? strings.onboardingWelcomeBenefit : strings.onboardingSubtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(strings.cancelLabel) { onDismiss() }
            }

            ScrollView {
                Group {
                    if step == .welcome {
                        welcomeStep
                    } else {
                        routineSelectionStep
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                if step == .routineSelection {
                    Button(strings.onboardingBackButtonTitle) {
                        step = .welcome
                    }
                }
                Spacer()
                if step == .welcome {
                    Button(strings.onboardingContinueButtonTitle) {
                        step = .routineSelection
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(strings.onboardingConfirmButtonTitle) {
                        store.confirmOnboarding(selection)
                        onConfirm()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 760, height: 640)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            welcomePoint(systemName: "heart.fill", text: strings.onboardingWelcomeBenefit)
            welcomePoint(systemName: "menubar.rectangle", text: strings.onboardingWelcomeMenuBar)
            welcomePoint(systemName: "clock.arrow.circlepath", text: strings.onboardingWelcomeSnooze)
            welcomePoint(systemName: "arrow.uturn.right.circle.fill", text: strings.onboardingWelcomeResume)
        }
    }

    private var routineSelectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            recommendedTemplates
            customRoutineSection
            todayPreview
        }
    }

    private func welcomePoint(systemName: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemName)
                .frame(width: 28)
                .foregroundStyle(PuzFullscreenTheme.accent)
            Text(text)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recommendedTemplates: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.routinesTitle)
                .font(.title3.bold())

            ForEach(templates, id: \.key) { template in
                Toggle(isOn: selectedBinding(for: template.key)) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: symbolName(for: template.actionType))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(strings.onboardingTemplateTitle(template.key))
                                .font(.headline)
                            Text(strings.onboardingTemplateIntent(template.key))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(template.dailyTimes.map(\.description).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                }
                .toggleStyle(.checkbox)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var customRoutineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(strings.makeMyOwnTitle, isOn: $customEnabled)
                .font(.title3.bold())
                .toggleStyle(.checkbox)

            if customEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(strings.customRoutineNamePlaceholder, text: $customName)
                        .textFieldStyle(.roundedBorder)

                    Picker(strings.actionLabel, selection: $customGlyphSymbolName) {
                        ForEach(glyphChoices, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Stepper(value: $customHour, in: 0...23) {
                            Text("\(strings.timeLabel): \(String(format: "%02d", customHour)):\(String(format: "%02d", customMinute))")
                        }
                        Stepper(value: $customMinute, in: 0...55, step: 5) {
                            Text(strings.minuteUnit)
                        }
                    }

                    Stepper(value: $customCount, in: 1...12) {
                        Text("\(strings.runsPerDayLabel): \(customCount)")
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var todayPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(strings.todayPreviewHeading)
                .font(.title3.bold())

            let items = OnboardingPreviewService().previewToday(selection: selection)
            if items.isEmpty {
                Text(strings.onboardingNoSelectionPreview)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.routineTitle)
                        Spacer()
                        Text(timeFormatter.string(from: item.date))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var selection: OnboardingSelection {
        OnboardingSelection(
            selectedTemplateKeys: templates.map(\.key).filter { selectedTemplateKeys.contains($0) },
            customDraft: customEnabled ? customDraft : nil
        )
    }

    private var customDraft: CustomRoutineDraft {
        CustomRoutineDraft(
            name: customName,
            glyphSymbolName: customGlyphSymbolName,
            dailyTime: DailyTime(hour: customHour, minute: customMinute),
            dailyCount: customCount
        )
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = strings.locale
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private func selectedBinding(for key: RecommendedPuzTemplateKey) -> Binding<Bool> {
        Binding(
            get: { selectedTemplateKeys.contains(key) },
            set: { isSelected in
                if isSelected {
                    selectedTemplateKeys.insert(key)
                } else {
                    selectedTemplateKeys.remove(key)
                }
            }
        )
    }

    private func symbolName(for actionType: ActionType) -> String {
        switch actionType {
        case .burpee, .exercise:
            return "figure.walk"
        case .standUp:
            return "figure.stand"
        case .drinkWater:
            return "drop"
        case .stretch:
            return "figure.walk"
        case .eyeRest:
            return "eye"
        }
    }
}
