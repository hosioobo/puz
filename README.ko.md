<p align="right">한국어 | <a href="./README.md">English</a></p>

# puz

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-0A84FF?style=for-the-badge&logo=apple&logoColor=white">
  <img alt="Swift 5.9+" src="https://img.shields.io/badge/Swift-5.9%2B-F05138?style=for-the-badge&logo=swift&logoColor=white">
  <img alt="Version 0.2.1" src="https://img.shields.io/badge/version-0.2.1-EEF4FF?style=for-the-badge">
  <a href="./LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-111111?style=for-the-badge"></a>
</p>

> 다시 움직이게 만드는 휴식 인터럽트.

puz는 운동/휴식 루틴을 쉽게 무시하지 못하게 만드는 작은 macOS 메뉴바 앱입니다. 전체화면 시작 프롬프트를 띄우고, 시작하면 연결된 모든 모니터를 덮는 카운트다운을 보여준 뒤, 마지막에 **Resume**을 눌러야 화면이 닫힙니다.

> **v0.2.1**은 현재 공개 릴리스입니다. `v0.2.0`은 다중 루틴 소스 체크포인트로 남아 있습니다.

## What is puz?

puz는 macOS 로컬에서 동작하는 루틴 인터럽터입니다. 메뉴바에 있다가 다음 일정이 되면 집중된 전체화면 흐름을 열어, 휴식/운동을 눈에 띄고 단순하고 덜 쉽게 넘길 수 있게 만듭니다.

현재 앱은 일부러 작게 유지합니다. 기본 루틴 세트, 간단한 설정 창 하나, 전체화면 프롬프트 흐름 하나, 그리고 설정/완료/건너뛰기 기록의 로컬 저장이 핵심입니다.

## Why puz?

일반 알림은 너무 쉽게 넘길 수 있습니다. puz는 “정말 잠깐 멈춰서 움직이기”를 화면 위에 확실히 올려두는 데 초점을 둡니다. 복잡한 생산성 앱이나 습관 대시보드가 아니라, 일을 다시 시작하기 전에 몸을 움직이게 하는 작은 인터럽트입니다.

## Features

- **메뉴바 앱** — `<//>` 느낌의 작은 identity와 설정 접근.
- **다중 루틴 스케줄링** — 활성 루틴이 요일, 시간 구간, 하루 횟수, 최소 간격, 배치 방식에서 daily virtual slot을 만듭니다.
- **전체화면 focus flow** — 프롬프트와 카운트다운이 모든 연결 모니터를 덮을 수 있음.
- **Resume 필수 완료** — 카운트다운이 끝나도 바로 닫히지 않고, 사용자가 **Resume**을 눌러야 돌아감.
- **미루기/건너뛰기 선택** — 짧게/길게/랜덤 미루기와 명시적 세션 종료 선택으로 완료 기록을 정확하게 유지.
- **로컬 기록** — 설정, 완료 기록, 건너뛰기 기록은 Mac에 저장.
- **시스템 언어 기반 문구** — 시스템 선호 언어에 따라 영어/한국어 앱 문구를 선택하고, 미지원 언어는 영어로 fallback.
- **테마 확장 준비** — 기본 시각 언어는 blue/off-white이고, Black & White 테마는 나중에 별도 옵션으로 추가 예정.

## Quick Install

### macOS zip 다운로드

최신 GitHub Release에서 [`puz-macos.zip`](https://github.com/hosioobo/puz/releases/latest/download/puz-macos.zip)을 다운로드하고, 압축을 푼 뒤 `puz.app`을 엽니다.

현재 앱은 아직 서명/공증되어 있지 않아서 macOS 첫 실행 시 수동 승인이 필요할 수 있습니다. Finder가 앱을 막으면 `puz.app`을 Control-click한 뒤 **Open**을 선택하고 확인하세요.

### Build from source

필요 조건:

- macOS 13+
- Swift 5.9+ / Xcode Command Line Tools

```bash
git clone https://github.com/hosioobo/puz.git
cd puz
swift run PauseCoreTestRunner
swift build --product PauseApp
Scripts/build_app.sh
```

### 소스 빌드 열기

```bash
open dist/puz.app
```

## Getting Started

### 1. Launch puz

압축을 푼 `puz.app`을 열거나, 소스에서 빌드했다면 `dist/puz.app`을 엽니다. puz는 Dock 앱이 아니라 메뉴바 앱으로 실행됩니다.

### 2. Configure your routine

설정 창에서 루틴 이름, 시간, 활성 요일, 시간 구간, 하루 실행 횟수, 최소 간격, 배치 방식, 미루기 제한을 조정합니다.

### 3. Wait for a prompt

다음 일정이 되면 puz가 전체화면 시작 프롬프트를 보여줍니다.

### 4. Start, snooze, or close

시작 프롬프트에서 세션을 시작하거나, 고정 시간으로 미루거나, 랜덤 시간으로 미루거나, 전체화면 흐름을 닫을 수 있습니다. `×`로 닫는 것은 완료 기록으로 저장하지 않습니다. 런타임 스케줄러가 루틴의 기본 일정 규칙에서 다음 트리거를 다시 계산하게 둡니다.

### 5. Resume when complete

카운트다운이 0이 되면 **Resume**을 눌러 전체화면 overlay를 닫고 작업으로 돌아갑니다.

## Fullscreen Flow

### Start Prompt

시작 프롬프트는 기본 blue/off-white 테마, 중앙 action symbol, 루틴 시간, 미루기 선택지를 보여줍니다. 미루기 남은 횟수는 세션 시작 전에 보여서 선택이 명확합니다.

### Countdown

카운트다운 화면은 원형 progress ring, action symbol, step hint, 남은 시간을 통해 루틴을 계속 눈에 띄게 둡니다. 원형 진행 표시는 남은 시간이 줄어들수록 시계방향으로 줄어듭니다.

### Completion / Resume

시간이 끝나면 overlay가 완료 상태로 바뀌고 **Resume** 버튼을 보여줍니다. Resume을 누르기 전까지 overlay는 유지됩니다.

### Snooze behavior

현재 흐름은 다음 미루기 방식을 지원합니다.

- 짧은 고정 미루기
- 긴 고정 미루기
- 랜덤 미루기
- 설정 가능한 최대 미루기 횟수

미루기는 시작 전 결정입니다. 활성 카운트다운 화면 안에는 미루기 버튼을 두지 않습니다.

## Scheduling Model

### Active days and time windows

현재 일정 모델은 여러 활성 루틴을 지원합니다. 각 루틴은 활성 요일, 하나 이상의 same-day 시간 구간, 하루 실행 횟수, 최소 간격, 고르게 배치/안정적 랜덤 배치 방식을 정의할 수 있습니다.

### Virtual slots

런타임에서는 루틴 규칙에서 구체적인 virtual slot을 만들고, 활성 루틴 전체에서 가장 이른 가능한 slot을 선택합니다. 완료/건너뛰기 기록에는 slot metadata를 함께 저장해서 한 slot의 완료가 같은 루틴의 이후 가능한 slot을 숨기지 않게 합니다.

### Compatibility

기존 지정 시각 루틴도 유지합니다. 지정 시각은 해당 시각의 virtual slot 하나로 매핑됩니다.

### Future schedule work

자정을 넘는 구간, 예외, quiet time, 더 정교한 미루기 정책은 오늘 암묵적으로 지원하는 동작이 아니라 별도 product decision으로 둡니다.

## Settings

현재 설정 창은 다음을 다룹니다.

- 루틴 목록 관리
- 활성 상태와 루틴 이름
- action type과 시간
- 활성 요일과 시간 구간
- 하루 실행 횟수, 최소 간격, 배치 방식
- 미루기 제한

언어는 현재 시스템 선호 언어를 따릅니다. 필요하면 나중에 앱 언어를 직접 고르는 설정을 추가할 수 있습니다.

## Themes

### Default Theme

puz의 기본 테마는 현재 전체화면에 적용된 blue/off-white 시각 시스템입니다.

### Planned Themes

- **Black & White** — 나중에 별도 theme 옵션으로 추가 예정.

## Screenshots

현재 SwiftUI 전체화면 view에서 생성한 스크린샷입니다. 데스크톱 내용은 포함하지 않습니다.

| 시작 프롬프트 | 카운트다운 |
| --- | --- |
| ![puz 전체화면 시작 프롬프트](docs/assets/screenshots/puz-start-prompt.png) | ![puz 전체화면 카운트다운](docs/assets/screenshots/puz-countdown.png) |

## Development

### Requirements

- macOS 13+
- Swift 5.9+ / Xcode Command Line Tools

### Run tests

이 프로젝트는 XCTest가 없는 Command Line Tools 환경에서도 돌릴 수 있도록 SwiftPM 실행형 테스트 러너를 사용합니다.

```bash
swift run PauseCoreTestRunner
```

테스트 러너는 일정 계산, 미루기 선택지/제한, 숫자 입력 sanitizer, 저장소, 완료 기록 동작, 영어/한국어 localization copy를 검증합니다.

### Build

```bash
swift build --product PauseApp
```

### Build app bundle

```bash
Scripts/build_app.sh
```

이 스크립트는 SwiftPM release 바이너리에서 `dist/puz.app`을 만듭니다.

## Project Structure

```text
Package.swift
  SwiftPM package definition
Sources/PauseCore
  모델, 스케줄 엔진, 미루기 선택지, 저장소, localization
Sources/PauseApp
  메뉴바 앱, 전체화면 프롬프트, 설정 창, 카운트다운 overlay
Sources/PauseCoreTestRunner
  커맨드라인 테스트 러너
Resources/Info.plist
  macOS 앱 번들 메타데이터
Scripts/build_app.sh
  SwiftPM release 바이너리에서 dist/puz.app 생성
docs/index.html
  텍스트-only 공개 홈페이지
```

SwiftPM target 이름은 아직 내부적으로 기존 `Pause*` prefix를 사용합니다. 앱 이름, bundle 이름, executable은 `puz`입니다.

## Roadmap

- 서명/공증된 release build.
- 짧은 demo media.
- 예외 / quiet time.
- 앱 언어 직접 선택.
- Black & White theme.

## Contributing

puz는 아직 초기 단계입니다. 기여한다면 작고, local-first이고, SwiftPM에서 쉽게 검증할 수 있는 변경을 선호합니다.

PR 전에 유용한 확인 명령:

```bash
swift run PauseCoreTestRunner
swift build --product PauseApp
Scripts/build_app.sh
```

## License

MIT. [`LICENSE`](./LICENSE)를 참고하세요.
