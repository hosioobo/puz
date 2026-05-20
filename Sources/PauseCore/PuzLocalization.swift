import Foundation

public enum PuzLanguage: String, Codable, CaseIterable, Equatable, Hashable {
    case english = "en"
    case korean = "ko"

    public static func preferred(from identifiers: [String] = Locale.preferredLanguages) -> PuzLanguage {
        for identifier in identifiers {
            let normalized = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
            if normalized == "ko" || normalized.hasPrefix("ko-") {
                return .korean
            }
            if normalized == "en" || normalized.hasPrefix("en-") {
                return .english
            }
        }
        return .english
    }
}

public struct PuzLocalization: Equatable, Hashable {
    public let language: PuzLanguage

    public init(language: PuzLanguage = .preferred()) {
        self.language = language
    }

    public static var current: PuzLocalization {
        PuzLocalization(language: .preferred())
    }

    public var locale: Locale {
        Locale(identifier: language == .korean ? "ko_KR" : "en_US_POSIX")
    }

    public var appMenuTitle: String { "<//> puz" }

    public func actionName(_ actionType: ActionType) -> String {
        switch language {
        case .english:
            switch actionType {
            case .burpee: return "Burpee"
            case .standUp: return "Stand up"
            case .drinkWater: return "Drink water"
            case .stretch: return "Stretch"
            case .eyeRest: return "Eye rest"
            case .exercise: return "Exercise"
            }
        case .korean:
            switch actionType {
            case .burpee: return "버피"
            case .standUp: return "일어나기"
            case .drinkWater: return "물 마시기"
            case .stretch: return "스트레칭"
            case .eyeRest: return "눈 쉬기"
            case .exercise: return "운동"
            }
        }
    }

    public func routineTitle(_ routine: Routine) -> String {
        let trimmed = routine.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return actionName(routine.actionType) }

        let builtInNames = Set(PuzLanguage.allCases.map { PuzLocalization(language: $0).actionName(routine.actionType) })
        if builtInNames.contains(trimmed) {
            return actionName(routine.actionType)
        }
        return trimmed
    }

    public func scheduleName(_ schedule: Schedule) -> String {
        switch (language, schedule) {
        case (.english, .fixedTime(let time)):
            return "Fixed time \(time)"
        case (.english, .randomWindow(let start, let end)):
            return "Random window \(start)–\(end)"
        case (.korean, .fixedTime(let time)):
            return "지정 시각 \(time)"
        case (.korean, .randomWindow(let start, let end)):
            return "랜덤 구간 \(start)–\(end)"
        }
    }

    public func minuteCount(_ minutes: Int) -> String {
        let value = max(0, minutes)
        switch language {
        case .english:
            return value == 1 ? "1 min" : "\(value) min"
        case .korean:
            return "\(value)분"
        }
    }

    public func sessionDurationPhrase(minutes: Int) -> String {
        let value = max(1, minutes)
        switch language {
        case .english:
            return "\(value) minute"
        case .korean:
            return "\(value)분"
        }
    }

    public func startSessionButtonTitle(duration: String) -> String {
        switch language {
        case .english:
            return "Start \(duration)"
        case .korean:
            return "\(duration) 시작"
        }
    }

    public func promptHeadline(for routine: Routine) -> String {
        let title = routineTitle(routine)
        switch language {
        case .english:
            switch routine.actionType {
            case .burpee: return "Time for burpees"
            case .standUp: return "Time to stand up"
            case .drinkWater: return "Time to hydrate"
            case .stretch: return "Time to stretch"
            case .eyeRest: return "Time to rest your eyes"
            case .exercise: return "Time to move"
            }
        case .korean:
            return "\(title) 할 시간이에요"
        }
    }

    public func promptActionDescription(actionType: ActionType, minutes: Int) -> String {
        let duration = sessionDurationPhrase(minutes: minutes)
        switch language {
        case .english:
            switch actionType {
            case .burpee:
                return "Take a \(duration) movement break for full-body energy."
            case .standUp:
                return "Take a \(duration) break to stand up and reset your posture."
            case .drinkWater:
                return "Take a \(duration) hydration break."
            case .stretch:
                return "Take a \(duration) break for shoulders, neck, and hips."
            case .eyeRest:
                return "Take a \(duration) eye break to look far away and blink slowly."
            case .exercise:
                return "Take a \(duration) movement break."
            }
        case .korean:
            switch actionType {
            case .burpee:
                return "전신 에너지를 위한 \(duration) 움직임 휴식이에요."
            case .standUp:
                return "자세를 다시 세우는 \(duration) 휴식이에요."
            case .drinkWater:
                return "물을 마시는 \(duration) 휴식이에요."
            case .stretch:
                return "어깨, 목, 고관절을 위한 \(duration) 휴식이에요."
            case .eyeRest:
                return "멀리 보고 천천히 깜빡이는 \(duration) 눈 휴식이에요."
            case .exercise:
                return "몸을 움직이는 \(duration) 휴식이에요."
            }
        }
    }

    public func focusText(for actionType: ActionType) -> String {
        switch language {
        case .english:
            switch actionType {
            case .burpee: return "Full-body energy"
            case .standUp: return "Posture and circulation"
            case .drinkWater: return "Hydration"
            case .stretch: return "Shoulders, neck, and hips"
            case .eyeRest: return "Look far away and blink slowly"
            case .exercise: return "Movement reset"
            }
        case .korean:
            switch actionType {
            case .burpee: return "전신 에너지"
            case .standUp: return "자세와 순환"
            case .drinkWater: return "수분 보충"
            case .stretch: return "어깨, 목, 고관절"
            case .eyeRest: return "멀리 보고 천천히 깜빡이기"
            case .exercise: return "움직임 리셋"
            }
        }
    }

    public func activeSessionTitle(for actionType: ActionType) -> String {
        switch language {
        case .english:
            switch actionType {
            case .burpee: return "Burpees"
            case .standUp: return "Standing up"
            case .drinkWater: return "Hydrating"
            case .stretch: return "Stretching"
            case .eyeRest: return "Resting eyes"
            case .exercise: return "Moving"
            }
        case .korean:
            switch actionType {
            case .burpee: return "버피 중"
            case .standUp: return "일어나는 중"
            case .drinkWater: return "물 마시는 중"
            case .stretch: return "스트레칭 중"
            case .eyeRest: return "눈 쉬는 중"
            case .exercise: return "움직이는 중"
            }
        }
    }

    public func sessionProgressText(minutes: Int) -> String {
        let duration = sessionDurationPhrase(minutes: minutes)
        switch language {
        case .english:
            return "\(duration) session in progress"
        case .korean:
            return "\(duration) 세션 진행 중"
        }
    }

    public func completionSubtitle(routineTitle: String, minutes: Int) -> String {
        let duration = sessionDurationPhrase(minutes: minutes)
        switch language {
        case .english:
            return "Your \(duration) \(routineTitle.lowercased()) is complete."
        case .korean:
            return "\(duration) \(routineTitle) 완료했어요."
        }
    }

    public func sessionStepLabels(for actionType: ActionType) -> [String] {
        switch language {
        case .english:
            switch actionType {
            case .burpee: return ["Warm up", "Steady pace", "Breathe"]
            case .standUp: return ["Stand tall", "Roll shoulders", "Look away"]
            case .drinkWater: return ["Sip water", "Breathe", "Reset"]
            case .stretch: return ["Roll shoulders", "Neck stretch", "Hip opener"]
            case .eyeRest: return ["Look far", "Relax eyes", "Blink slowly"]
            case .exercise: return ["Move gently", "Keep form", "Cool down"]
            }
        case .korean:
            switch actionType {
            case .burpee: return ["가볍게 시작", "일정한 속도", "호흡"]
            case .standUp: return ["바르게 서기", "어깨 돌리기", "멀리 보기"]
            case .drinkWater: return ["물 마시기", "호흡", "리셋"]
            case .stretch: return ["어깨 돌리기", "목 풀기", "고관절 열기"]
            case .eyeRest: return ["멀리 보기", "눈 힘 빼기", "천천히 깜빡이기"]
            case .exercise: return ["천천히 움직이기", "자세 유지", "마무리"]
            }
        }
    }

    public func snoozeButtonTitle(_ option: SnoozeDelayOption) -> String {
        switch language {
        case .english:
            switch option {
            case .oneMinute: return "Snooze 1 min"
            case .thirtyMinutes: return "Snooze 30 min"
            case .random: return "Random snooze"
            }
        case .korean:
            switch option {
            case .oneMinute: return "1분 미루기"
            case .thirtyMinutes: return "30분 미루기"
            case .random: return "랜덤 미루기"
            }
        }
    }

    public func snoozeButtonSubtitle(_ option: SnoozeDelayOption) -> String? {
        guard option == .random else { return nil }
        let range = SnoozeDelayOption.randomMinuteRange
        switch language {
        case .english:
            return "\(range.lowerBound)–\(range.upperBound) min"
        case .korean:
            return "\(range.lowerBound)–\(range.upperBound)분"
        }
    }

    public func snoozeRemainingText(count: Int) -> String {
        let remaining = max(0, count)
        switch language {
        case .english:
            return remaining == 1 ? "1 snooze left" : "\(remaining) snoozes left"
        case .korean:
            return "미루기 \(remaining)회 남음"
        }
    }

    public var menuNextCalculating: String {
        switch language {
        case .english: return "Next: calculating"
        case .korean: return "다음: 계산 중"
        }
    }

    public func menuNext(dateText: String?) -> String {
        guard let dateText else {
            switch language {
            case .english: return "Next: none"
            case .korean: return "다음: 없음"
            }
        }
        switch language {
        case .english: return "Next: \(dateText)"
        case .korean: return "다음: \(dateText)"
        }
    }

    public func menuNext(routineTitle: String?, dateText: String?) -> String {
        guard let routineTitle, let dateText else {
            switch language {
            case .english: return "Next: none"
            case .korean: return "다음: 없음"
            }
        }
        switch language {
        case .english: return "Next: \(routineTitle) at \(dateText)"
        case .korean: return "다음: \(routineTitle) · \(dateText)"
        }
    }

    public var menuNoRoutines: String {
        switch language {
        case .english: return "No routines"
        case .korean: return "루틴 없음"
        }
    }

    public var menuSetupIncomplete: String {
        switch language {
        case .english: return "Setup incomplete"
        case .korean: return "설정 미완료"
        }
    }

    public var finishSetupLabel: String {
        switch language {
        case .english: return "Finish setup"
        case .korean: return "설정 마치기"
        }
    }

    public var onboardingTitle: String {
        switch language {
        case .english: return "Set up your first puz"
        case .korean: return "첫 puz를 설정해요"
        }
    }

    public var onboardingSubtitle: String {
        switch language {
        case .english: return "Pick small fullscreen breaks. Nothing starts until you confirm."
        case .korean: return "작은 전체화면 휴식을 골라요. 확인하기 전에는 시작되지 않아요."
        }
    }

    public var onboardingWelcomeTitle: String {
        switch language {
        case .english: return "Build a healthier break habit"
        case .korean: return "건강한 휴식 습관을 만들어요"
        }
    }

    public var onboardingWelcomeBenefit: String {
        switch language {
        case .english: return "Step out of over-focus for a quick body-and-mind recharge."
        case .korean: return "과도한 몰입에서 잠시 벗어나 몸과 마음의 재충전을 도와요."
        }
    }

    public var onboardingWelcomeMenuBar: String {
        switch language {
        case .english: return "puz stays in the menu bar, then appears fullscreen by your rules."
        case .korean: return "평소에는 메뉴바에 있고, 지정한 규칙에 따라 전체 화면으로 등장해요."
        }
    }

    public var onboardingWelcomeSnooze: String {
        switch language {
        case .english: return "Use 1-minute or 30-minute snooze when work needs flexibility."
        case .korean: return "1분, 30분 미루기로 업무 상황에 맞게 조절할 수 있어요."
        }
    }

    public var onboardingWelcomeResume: String {
        switch language {
        case .english: return "When the countdown ends, press Resume and return fresh."
        case .korean: return "카운트다운이 끝나면 Resume으로 돌아와 fresh하게 다시 집중하세요."
        }
    }

    public var onboardingContinueButtonTitle: String {
        switch language {
        case .english: return "Continue"
        case .korean: return "계속하기"
        }
    }

    public var onboardingBackButtonTitle: String {
        switch language {
        case .english: return "Back"
        case .korean: return "뒤로"
        }
    }

    public func onboardingTemplateTitle(_ key: RecommendedPuzTemplateKey) -> String {
        switch (language, key) {
        case (.english, .hydrate): return "Hydrate"
        case (.english, .stretch): return "Stretch"
        case (.english, .eyeRest): return "Eye rest"
        case (.korean, .hydrate): return "물 마시기"
        case (.korean, .stretch): return "스트레칭"
        case (.korean, .eyeRest): return "눈 쉬기"
        }
    }

    public func onboardingTemplateIntent(_ key: RecommendedPuzTemplateKey) -> String {
        switch (language, key) {
        case (.english, .hydrate): return "A quick water reset at useful points in the day."
        case (.english, .stretch): return "Short shoulder, neck, and hip resets."
        case (.english, .eyeRest): return "Look far away and blink slowly."
        case (.korean, .hydrate): return "하루 중 필요한 때에 물 한 모금 리셋."
        case (.korean, .stretch): return "어깨, 목, 고관절을 짧게 풀어요."
        case (.korean, .eyeRest): return "멀리 보고 천천히 깜빡여요."
        }
    }

    public var makeMyOwnTitle: String {
        switch language {
        case .english: return "Make my own"
        case .korean: return "직접 만들기"
        }
    }

    public var customRoutineNamePlaceholder: String {
        switch language {
        case .english: return "Walk outside"
        case .korean: return "밖에 걷기"
        }
    }

    public var todayPreviewHeading: String {
        switch language {
        case .english: return "Today preview"
        case .korean: return "오늘 미리보기"
        }
    }

    public var onboardingNoSelectionPreview: String {
        switch language {
        case .english: return "No puz selected yet"
        case .korean: return "아직 선택한 puz가 없어요"
        }
    }

    public var onboardingConfirmButtonTitle: String {
        switch language {
        case .english: return "Start with these puz"
        case .korean: return "이 puz로 시작하기"
        }
    }

    public var advancedSettingsTitle: String {
        switch language {
        case .english: return "Advanced schedule"
        case .korean: return "고급 일정"
        }
    }

    public func todayCompleted(count: Int) -> String {
        switch language {
        case .english: return "Completed today: \(count)"
        case .korean: return "오늘 완료: \(count)"
        }
    }

    public func todayProgress(completed: Int, total: Int) -> String {
        let completed = max(0, completed)
        let total = max(0, total)
        switch language {
        case .english: return "Today: \(completed)/\(total) completed"
        case .korean: return "오늘: \(completed)/\(total) 완료"
        }
    }

    public var startNow: String {
        switch language {
        case .english: return "Start now"
        case .korean: return "지금 시작"
        }
    }

    public var settingsTitle: String {
        switch language {
        case .english: return "puz settings"
        case .korean: return "puz 설정"
        }
    }

    public var quit: String {
        switch language {
        case .english: return "Quit"
        case .korean: return "종료"
        }
    }

    public var fullscreenCloseAccessibilityLabel: String {
        switch language {
        case .english: return "Close fullscreen"
        case .korean: return "전체 화면 닫기"
        }
    }

    public func promptTitle(routineTitle: String) -> String {
        switch language {
        case .english: return "Time for \(routineTitle)"
        case .korean: return "\(routineTitle) 할 시간이에요"
        }
    }

    public func promptSubtitle(scheduledTime: String, duration: String) -> String {
        switch language {
        case .english: return "\(scheduledTime) slot · \(duration) countdown"
        case .korean: return "\(scheduledTime) 차례 · \(duration) 카운트다운"
        }
    }

    public var promptHelper: String {
        switch language {
        case .english: return "Start begins the fullscreen countdown. Snooze asks again later. Resume appears after the timer."
        case .korean: return "시작하면 전체 화면 카운트다운이 진행돼요. 미루기는 나중에 다시 묻고, Resume은 타이머 후에 나타나요."
        }
    }

    public var appQuit: String {
        switch language {
        case .english: return "Quit app"
        case .korean: return "앱 종료"
        }
    }

    public var countdownCancelAccessibilityLabel: String {
        switch language {
        case .english: return "Cancel countdown"
        case .korean: return "카운트다운 취소"
        }
    }

    public var endSessionTitle: String {
        switch language {
        case .english: return "End this session?"
        case .korean: return "이 세션을 끝낼까요?"
        }
    }

    public var endSessionMessage: String {
        switch language {
        case .english: return "Nothing will be marked complete. Choose how puz should handle this slot."
        case .korean: return "완료로 기록하지 않아요. 이 슬롯을 어떻게 처리할지 골라 주세요."
        }
    }

    public func endSessionActionTitle(_ action: SessionEndAction) -> String {
        switch (language, action) {
        case (.english, .remindMeLater): return "Ask me later"
        case (.english, .skipToday): return "Skip today"
        case (.english, .justClose): return "Close only"
        case (.korean, .remindMeLater): return "나중에 다시 묻기"
        case (.korean, .skipToday): return "오늘은 건너뛰기"
        case (.korean, .justClose): return "닫기만"
        }
    }

    public func endSessionActionSubtitle(_ action: SessionEndAction, canSnooze: Bool = true) -> String {
        switch (language, action, canSnooze) {
        case (.english, .remindMeLater, true): return "Use one snooze and ask again after a random delay."
        case (.english, .remindMeLater, false): return "No snoozes left."
        case (.english, .skipToday, _): return "Do not ask again for this routine today."
        case (.english, .justClose, _): return "No completion, no skip, no snooze."
        case (.korean, .remindMeLater, true): return "미루기 1회를 쓰고 랜덤 시간 뒤에 다시 물어요."
        case (.korean, .remindMeLater, false): return "남은 미루기가 없어요."
        case (.korean, .skipToday, _): return "오늘 이 루틴은 다시 묻지 않아요."
        case (.korean, .justClose, _): return "완료/건너뛰기/미루기 기록을 남기지 않아요."
        }
    }

    public var endSessionKeepGoingTitle: String {
        switch language {
        case .english: return "Keep going"
        case .korean: return "계속하기"
        }
    }

    public var countdownCompleteTitle: String {
        switch language {
        case .english: return "Nice work"
        case .korean: return "잘했어요"
        }
    }

    public var resumeInstruction: String {
        switch language {
        case .english: return "Press Resume to return to your screen."
        case .korean: return "Resume을 눌러 화면으로 돌아가요."
        }
    }

    public var resumeButtonTitle: String { "Resume" }

    public var countdownProgressInstruction: String {
        switch language {
        case .english: return "Resume will appear when the timer ends."
        case .korean: return "타이머가 끝나면 Resume 버튼이 나타나요."
        }
    }


    public var enabledLabel: String {
        switch language {
        case .english: return "Enabled"
        case .korean: return "활성화"
        }
    }

    public var routineNamePlaceholder: String {
        switch language {
        case .english: return "Routine name"
        case .korean: return "루틴 이름"
        }
    }

    public var actionLabel: String {
        switch language {
        case .english: return "Action"
        case .korean: return "행동"
        }
    }

    public var scheduleLabel: String {
        switch language {
        case .english: return "Schedule"
        case .korean: return "일정"
        }
    }

    public var randomWindowLabel: String {
        switch language {
        case .english: return "Random window"
        case .korean: return "랜덤 구간"
        }
    }

    public var fixedTimeLabel: String {
        switch language {
        case .english: return "Fixed time"
        case .korean: return "지정 시각"
        }
    }

    public var startLabel: String {
        switch language {
        case .english: return "Start"
        case .korean: return "시작"
        }
    }

    public var endLabel: String {
        switch language {
        case .english: return "End"
        case .korean: return "종료"
        }
    }

    public var timeLabel: String {
        switch language {
        case .english: return "Time"
        case .korean: return "시각"
        }
    }

    public var countdownLabel: String {
        switch language {
        case .english: return "Countdown"
        case .korean: return "카운트다운"
        }
    }

    public var minuteUnit: String {
        switch language {
        case .english: return "min"
        case .korean: return "분"
        }
    }

    public var preciseInputHint: String {
        switch language {
        case .english: return "click to enter an exact value"
        case .korean: return "클릭해서 직접 입력 가능"
        }
    }

    public var maxSnoozeLabel: String {
        switch language {
        case .english: return "Max snoozes"
        case .korean: return "미루기 최대"
        }
    }

    public var countUnit: String {
        switch language {
        case .english: return "times"
        case .korean: return "회"
        }
    }

    public var snoozeDisplayHint: String {
        switch language {
        case .english: return "shown as remaining count on the start screen"
        case .korean: return "시작 화면에 남은 횟수로 표시"
        }
    }

    public var timeEditorHint: String {
        switch language {
        case .english: return "Use steppers for quick time changes; click a number field for exact input."
        case .korean: return "시간은 스테퍼로 빠르게 조정하고, 숫자 칸을 클릭하면 정확히 입력할 수 있어요."
        }
    }

    public var snoozeButtonsHint: String {
        switch language {
        case .english: return "Choose snooze delay on the start screen: 1 min / 30 min / random."
        case .korean: return "미루기는 시작 화면에서 1분 후 / 30분 후 / 랜덤 버튼으로 고릅니다."
        }
    }

    public var saveLabel: String {
        switch language {
        case .english: return "Save"
        case .korean: return "저장"
        }
    }

    public var cancelLabel: String {
        switch language {
        case .english: return "Cancel"
        case .korean: return "취소"
        }
    }

    public var routinesTitle: String {
        switch language {
        case .english: return "Routines"
        case .korean: return "루틴"
        }
    }

    public var newRoutineLabel: String {
        switch language {
        case .english: return "New"
        case .korean: return "새로 만들기"
        }
    }

    public var deleteRoutineLabel: String {
        switch language {
        case .english: return "Delete"
        case .korean: return "삭제"
        }
    }

    public var duplicateRoutineLabel: String {
        switch language {
        case .english: return "Duplicate"
        case .korean: return "복제"
        }
    }

    public var noRoutinesTitle: String {
        switch language {
        case .english: return "No routines yet"
        case .korean: return "아직 루틴이 없어요"
        }
    }

    public var noRoutinesMessage: String {
        switch language {
        case .english: return "Create a routine to start the puz schedule."
        case .korean: return "새 루틴을 만들면 puz 일정을 시작할 수 있어요."
        }
    }

    public var selectRoutineMessage: String {
        switch language {
        case .english: return "Select a routine to edit it."
        case .korean: return "편집할 루틴을 선택해 주세요."
        }
    }

    public var basicsSectionTitle: String {
        switch language {
        case .english: return "Basics"
        case .korean: return "기본"
        }
    }

    public var whenSectionTitle: String {
        switch language {
        case .english: return "When"
        case .korean: return "언제"
        }
    }

    public var howOftenSectionTitle: String {
        switch language {
        case .english: return "How often"
        case .korean: return "얼마나 자주"
        }
    }

    public var weekdaysLabel: String {
        switch language {
        case .english: return "Days"
        case .korean: return "요일"
        }
    }

    public var windowsLabel: String {
        switch language {
        case .english: return "Windows"
        case .korean: return "시간 구간"
        }
    }

    public var addWindowLabel: String {
        switch language {
        case .english: return "Add window"
        case .korean: return "구간 추가"
        }
    }

    public var deleteWindowLabel: String {
        switch language {
        case .english: return "Delete window"
        case .korean: return "구간 삭제"
        }
    }

    public var windowLabelPlaceholder: String {
        switch language {
        case .english: return "Window label"
        case .korean: return "구간 이름"
        }
    }

    public var runsPerDayLabel: String {
        switch language {
        case .english: return "Runs per day"
        case .korean: return "하루 실행 횟수"
        }
    }

    public var minimumGapLabel: String {
        switch language {
        case .english: return "Minimum gap"
        case .korean: return "최소 간격"
        }
    }

    public var distributionLabel: String {
        switch language {
        case .english: return "Distribution"
        case .korean: return "배치 방식"
        }
    }

    public var unsavedChangesLabel: String {
        switch language {
        case .english: return "Unsaved changes"
        case .korean: return "저장하지 않은 변경이 있어요"
        }
    }

    public var newRoutineDefaultTitle: String {
        switch language {
        case .english: return "New Puz"
        case .korean: return "새 Puz"
        }
    }

    public func copiedRoutineTitle(_ title: String) -> String {
        switch language {
        case .english: return "\(title) copy"
        case .korean: return "\(title) 복사본"
        }
    }

    public func weekdayShortName(_ weekday: Weekday) -> String {
        switch (language, weekday) {
        case (.english, .sunday): return "Sun"
        case (.english, .monday): return "Mon"
        case (.english, .tuesday): return "Tue"
        case (.english, .wednesday): return "Wed"
        case (.english, .thursday): return "Thu"
        case (.english, .friday): return "Fri"
        case (.english, .saturday): return "Sat"
        case (.korean, .sunday): return "일"
        case (.korean, .monday): return "월"
        case (.korean, .tuesday): return "화"
        case (.korean, .wednesday): return "수"
        case (.korean, .thursday): return "목"
        case (.korean, .friday): return "금"
        case (.korean, .saturday): return "토"
        }
    }

    public func distributionName(_ mode: DistributionMode) -> String {
        switch (language, mode) {
        case (.english, .evenlySpread): return "Evenly spread"
        case (.english, .random): return "Stable random"
        case (.korean, .evenlySpread): return "고르게 배치"
        case (.korean, .random): return "안정적 랜덤"
        }
    }

    public func routineWindowSummary(start: DailyTime, end: DailyTime) -> String {
        switch language {
        case .english: return "\(start)–\(end)"
        case .korean: return "\(start)–\(end)"
        }
    }

    public func routineRunsSummary(runsPerDay: Int) -> String {
        switch language {
        case .english: return runsPerDay == 1 ? "1 time/day" : "\(runsPerDay) times/day"
        case .korean: return "하루 \(runsPerDay)회"
        }
    }

    public func validationNoWeekdays(routineTitle: String) -> String {
        switch language {
        case .english: return "\(routineTitle) needs at least one day."
        case .korean: return "\(routineTitle)에 요일을 하나 이상 선택해 주세요."
        }
    }

    public func validationNoWindows(routineTitle: String) -> String {
        switch language {
        case .english: return "\(routineTitle) needs at least one time window."
        case .korean: return "\(routineTitle)에 시간 구간을 하나 이상 추가해 주세요."
        }
    }

    public func validationInvalidWindow(routineTitle: String) -> String {
        switch language {
        case .english: return "\(routineTitle) has a window where start must be before end."
        case .korean: return "\(routineTitle)의 시간 구간은 시작이 종료보다 빨라야 해요."
        }
    }

    public func validationOverlappingWindows(routineTitle: String) -> String {
        switch language {
        case .english: return "\(routineTitle) has overlapping time windows."
        case .korean: return "\(routineTitle)에 겹치는 시간 구간이 있어요."
        }
    }

    public func validationImpossibleFrequency(routineTitle: String) -> String {
        switch language {
        case .english: return "\(routineTitle) cannot fit that many runs with the current minimum gap."
        case .korean: return "\(routineTitle)은 현재 최소 간격으로 하루 실행 횟수를 넣을 수 없어요."
        }
    }
}
