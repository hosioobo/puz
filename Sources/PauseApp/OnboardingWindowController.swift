import AppKit
import SwiftUI
import PauseCore

final class OnboardingWindowController: NSObject, NSWindowDelegate {
    var onConfirm: (() -> Void)?
    var onOpenSettings: (() -> Void)?

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
            onOpenSettings: { [weak self] in
                self?.window?.orderOut(nil)
                self?.onConfirm?()
                self?.onOpenSettings?()
            },
            onDismiss: { [weak self] in
                self?.closeAsDismissed()
            }
        )

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: OnboardingWindowMetrics.initialSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = strings.onboardingTitle
            window.minSize = OnboardingWindowMetrics.minimumSize
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

private enum OnboardingWindowMetrics {
    static let initialSize = NSSize(width: 820, height: 760)
    static let minimumSize = NSSize(width: 760, height: 640)
}

private enum OnboardingStep {
    case welcome
    case routineSelection
}

private struct OnboardingView: View {
    let store: RoutineStore
    let onConfirm: () -> Void
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    private let strings = PuzLocalization.current
    private let templates = RecommendedPuzTemplate.defaults
    private let glyphChoices = OnboardingGlyphChoice.defaults

    @State private var selectedTemplateKeys: Set<RecommendedPuzTemplateKey>
    @State private var customEnabled = false
    @State private var customName = ""
    @State private var customGlyphSymbolName = "figure.walk"
    @State private var customHour = 16
    @State private var customMinute = 0
    @State private var customCount = 1
    @State private var step = OnboardingStep.welcome

    init(
        store: RoutineStore,
        onConfirm: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.onConfirm = onConfirm
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
        let preselected = RecommendedPuzTemplate.defaults
            .filter(\.isPreselected)
            .map(\.key)
        _selectedTemplateKeys = State(initialValue: Set(preselected))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            scrollingContent
            footer
        }
        .padding(24)
        .frame(
            minWidth: OnboardingWindowMetrics.minimumSize.width,
            idealWidth: OnboardingWindowMetrics.initialSize.width,
            maxWidth: .infinity,
            minHeight: OnboardingWindowMetrics.minimumSize.height,
            idealHeight: OnboardingWindowMetrics.initialSize.height,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private var header: some View {
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
    }

    private var scrollingContent: some View {
        ScrollView {
            Group {
                if step == .welcome {
                    welcomeStep
                } else {
                    routineSelectionStep
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
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
                Button(primaryButtonTitle) {
                    performPrimaryAction()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            welcomePoint(systemName: "heart.fill", text: strings.onboardingWelcomeBenefit)
            welcomePoint(systemName: "menubar.rectangle", text: strings.onboardingWelcomeMenuBar)
            welcomePoint(systemName: "clock.arrow.circlepath", text: strings.onboardingWelcomeSnooze)
            welcomePoint(systemName: "arrow.uturn.right.circle.fill", text: strings.onboardingWelcomeResume)
        }
    }

    private var primaryButtonTitle: String {
        selection.hasAnyRoutine ? strings.onboardingConfirmButtonTitle : strings.onboardingOpenSettingsButtonTitle
    }

    private func performPrimaryAction() {
        let currentSelection = selection
        if currentSelection.hasAnyRoutine {
            store.confirmOnboarding(currentSelection)
            onConfirm()
        } else {
            store.markOnboardingDismissedBeforeConfirm()
            onOpenSettings()
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

                    Picker(strings.glyphLabel, selection: $customGlyphSymbolName) {
                        ForEach(glyphChoices, id: \.symbolName) { choice in
                            Label(choice.title, systemImage: choice.symbolName).tag(choice.symbolName)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack(spacing: 8) {
                        Text(strings.timeLabel)
                        TimeStepper(hour: $customHour, minute: $customMinute)
                    }

                    Stepper(value: $customCount, in: 1...12) {
                        HStack(spacing: 8) {
                            Text(strings.runsPerDayLabel)
                            NumericTimeField(value: $customCount, range: 1...12, width: 44, padded: false)
                            Text(strings.countUnit)
                        }
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
