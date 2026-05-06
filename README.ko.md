<p align="right">한국어 | <a href="./README.md">English</a></p>

# puz

puz는 운동/휴식 루틴을 쉽게 무시하지 못하게 만드는 macOS 메뉴바 앱입니다.
전체화면 시작 프롬프트를 띄우고, 시작하면 연결된 모든 모니터를 덮는 카운트다운을 보여준 뒤, 마지막에 **Resume**을 눌러야 화면이 닫힙니다.

> **v0.1.0**은 첫 공개 소스 체크포인트입니다. 아직 서명/공증된 배포용 바이너리는 아닙니다.

## 왜 만들었나요

일반 알림은 너무 쉽게 넘길 수 있습니다. puz는 “정말 잠깐 멈춰서 움직이기”를 화면 위에 확실히 올려두는 데 초점을 둡니다. 복잡한 생산성 앱보다는 작고 직접적인 루틴 인터럽트입니다.

## 현재 동작

- `<//>` 느낌의 작은 메뉴바 앱.
- 기본 루틴: 버피.
- 기본 시간: 10분.
- 기본 일정: 09:00–18:00 사이 하루 한 번 랜덤.
- 시작 프롬프트: **Start**, **1분 후**, **30분 후**, **랜덤**, **Quit**.
- 시작 전에 `미루기 n회 남음` 표시.
- 모든 연결 모니터를 덮는 전체화면 프롬프트와 카운트다운.
- 전체화면 우측 상단의 작은 `×` 취소 버튼.
- 전체화면 진입 시 짧은 시각 플래시.
- 타이머 주변의 시계방향으로 줄어드는 원형 진행 표시.
- 완료 기록 로컬 저장.
- 루틴 이름, 시간, 일정, 미루기 제한을 바꾸는 설정 창.

## 일정 모델

v0.1.0의 일정 모델은 일부러 작게 유지합니다.

- 지정 시각, 또는
- 하루 랜덤 시간 구간.

런타임 스케줄러는 현재 시각과 활성 루틴 설정을 기준으로 core schedule engine에 다음 트리거를 묻습니다. `×`로 닫는 것은 완료 처리로 기록하지 않고, 루틴의 기본 일정 규칙에서 다음 트리거를 다시 계산하게 둡니다.

## 텍스트-only 홈페이지

간단한 공개 페이지는 여기 있습니다.

- <https://hosioobo.github.io/puz/>
- [`docs/index.html`](./docs/index.html)

이번 릴리스에서는 스크린샷을 의도적으로 넣지 않았습니다.

## 소스에서 빌드

필요 조건:

- macOS 13+
- Swift 5.9+ / Xcode Command Line Tools

```bash
git clone https://github.com/hosioobo/puz.git
cd puz
swift run PauseCoreTestRunner
swift build --product PauseApp
```

로컬 `.app` 번들 생성:

```bash
Scripts/build_app.sh
open dist/puz.app
```

## 테스트

이 프로젝트는 XCTest가 없는 Command Line Tools 환경에서도 돌릴 수 있도록 SwiftPM 실행형 테스트 러너를 사용합니다.

```bash
swift run PauseCoreTestRunner
```

검증 범위:

- 지정 시각 스케줄 계산
- 랜덤 구간 스케줄 계산
- 비활성 루틴 제외
- 미루기 선택지와 제한
- 숫자 입력 sanitizer
- 기본 버피 루틴
- 루틴 로컬 저장
- 완료 기록 로컬 저장
- 완료 기록이 있는 상태의 런타임 트리거 계산

## 버전 관리

- 현재 버전: [`v0.1.0`](./VERSION)
- 변경 기록: [`CHANGELOG.md`](./CHANGELOG.md)
- 릴리스 규칙: [`VERSIONING.md`](./VERSIONING.md)

## macOS 한계

puz는 강제 종료, Activity Monitor 종료, 시스템 종료, 절전, 모든 Spaces/fullscreen edge case를 막을 수는 없습니다. 알림 권한이 거부되면 macOS 알림 배너는 안 보일 수 있지만, 앱 내부 프롬프트는 동작합니다.

## 프로젝트 구조

```text
Sources/PauseCore
  모델, 스케줄 엔진, 미루기 선택지, 저장소
Sources/PauseApp
  메뉴바 앱, 전체화면 프롬프트, 설정 창, 오버레이
Sources/PauseCoreTestRunner
  커맨드라인 테스트 러너
Resources/Info.plist
  macOS 앱 번들 메타데이터
Scripts/build_app.sh
  SwiftPM release 바이너리에서 dist/puz.app 생성
docs/index.html
  텍스트-only 공개 홈페이지
```
