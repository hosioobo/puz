<p align="right"><a href="./README.ko.md">한국어</a> | English</p>

# puz

puz is a small macOS menu bar app for movement breaks that are intentionally hard to ignore.
It can show a fullscreen prompt, cover every connected display during the countdown, and return control only after you press **Resume**.

> **v0.1.0** is the first public source checkpoint. It is not distributed as a signed or notarized binary yet.

## Why

Regular reminders are easy to dismiss. puz is designed for the moment when you want a break routine to become a real interruption: visible, simple, and slightly harder to negotiate away.

## Current behavior

- Menu bar app with a compact `<//>`-style identity.
- Default routine: burpees.
- Default duration: 10 minutes.
- Default schedule: one random trigger inside 09:00–18:00.
- Start prompt with **Start**, **1 min later**, **30 min later**, **Random**, and **Quit**.
- Snooze limit shown before starting: `n snoozes left`.
- Fullscreen prompt and countdown across all connected displays.
- A small top-right `×` cancel affordance for dismissing the fullscreen flow.
- A short visual flash when the fullscreen prompt appears.
- Clockwise shrinking circular progress around the timer.
- Completion records saved locally.
- Settings window for routine name, duration, schedule, and snooze limit.

## Scheduling model

puz keeps the v0.1.0 schedule model deliberately small:

- fixed time, or
- random time inside a daily window.

The runtime scheduler asks the core schedule engine for the next valid trigger from the current time and active routine settings. Dismissing with `×` does not mark the routine complete; it simply lets the app recompute the next trigger from the routine's normal schedule.

## Text-only homepage

A minimal text-only public page lives at:

- <https://hosioobo.github.io/puz/>
- [`docs/index.html`](./docs/index.html)

Screenshots are intentionally omitted for this release.

## Build from source

Requirements:

- macOS 13+
- Swift 5.9+ / Xcode Command Line Tools

```bash
git clone https://github.com/hosioobo/puz.git
cd puz
swift run PauseCoreTestRunner
swift build --product PauseApp
```

Create a local `.app` bundle:

```bash
Scripts/build_app.sh
open dist/puz.app
```

## Tests

This project uses a SwiftPM executable test runner so it can run in Command Line Tools environments where XCTest may not be available.

```bash
swift run PauseCoreTestRunner
```

The runner covers:

- fixed-time scheduling
- random-window scheduling
- disabled routine exclusion
- snooze options and limits
- numeric input sanitizing
- default burpee routine
- local routine persistence
- completion record persistence
- runtime trigger calculation with completion records

## Versioning

- Current version: [`v0.1.0`](./VERSION)
- Version history: [`CHANGELOG.md`](./CHANGELOG.md)
- Release policy: [`VERSIONING.md`](./VERSIONING.md)

## macOS limits

puz cannot block force quit, Activity Monitor termination, shutdown, sleep, or every possible Spaces/fullscreen edge case. If notification permission is denied, the in-app prompt still works but macOS notification banners may not.

## Project structure

```text
Sources/PauseCore
  Models, schedule engine, snooze choices, persistence
Sources/PauseApp
  Menu bar app, fullscreen prompt, settings window, overlay
Sources/PauseCoreTestRunner
  Command-line test runner
Resources/Info.plist
  macOS app bundle metadata
Scripts/build_app.sh
  Builds dist/puz.app from the SwiftPM release binary
docs/index.html
  Text-only public homepage
```
