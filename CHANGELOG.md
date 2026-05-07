# Changelog

All notable public changes to puz are recorded here.

## [v0.2.0] - 2026-05-07

### Added

- Core `PuzLocalization` catalog for English and Korean app copy.
- System-preferred language selection with English fallback.
- Localized menu bar, fullscreen prompt, countdown overlay, notification, and settings-window strings.
- Tests for language selection and representative Korean/English copy.
- Multi-routine model with enable/disable, active weekdays, same-day windows, runs per day, minimum gaps, and evenly-spread or stable-random distribution.
- Derived virtual slots for each routine run, including `scheduledAt` and `slotKey` metadata on completion and skip records.
- Routine-list settings editor with add, duplicate, delete, weekday, window, frequency, and distribution controls.
- Menu summaries for the next routine, today's completion progress, and empty-routine state.

### Changed

- App metadata now targets version `0.2.0` with build number `2` for the next development line.
- Runtime scheduling now chooses the earliest available virtual slot across enabled routines.
- Fresh v2 stores now default to `Stretch`, `Hydrate`, and `Stand up`; legacy v1 routine data resets to the v2 defaults by design.

### Fixed

- Preserved legacy fixed-time runtime scheduling by treating fixed-time zero-length windows as one virtual slot with slot metadata.

## [v0.1.0] - 2026-05-06

### Added

- First public source checkpoint for the macOS menu bar app.
- Fullscreen routine prompt and multi-display countdown overlay.
- Start, fixed-delay snooze, random snooze, cancel, and quit controls.
- Snooze-limit display and settings.
- Random-window and fixed-time scheduling.
- Runtime schedule recomputation through the core schedule engine.
- Local routine and completion-record persistence.
- SwiftPM executable test runner for CLT-friendly verification.
- Manual `.app` bundle build script.
- English and Korean README pair.
- Text-only homepage under `docs/index.html`.

### Notes

- No screenshots or screen recordings are included in this release.
- No signed/notarized binary is published yet.
