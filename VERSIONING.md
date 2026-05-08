# Versioning

puz uses SemVer-style versions starting at `v0.1.0`.

## Version fields

For each release, keep these in sync:

- `VERSION` — plain version number without the leading `v`.
- `Resources/Info.plist` → `CFBundleShortVersionString` — same value as `VERSION`.
- `Resources/Info.plist` → `CFBundleVersion` — monotonically increasing build number.
- `CHANGELOG.md` — human-readable release notes.
- Git tag — `v<version>`, for example `v0.1.0`.

## Release checklist

1. Update `VERSION`.
2. Update `Resources/Info.plist` version/build fields.
3. Update `CHANGELOG.md`.
4. Run verification:
   - `swift run PauseCoreTestRunner`
   - `swift build --product PauseApp`
   - `Scripts/build_app.sh`
5. Confirm the public tree does not include local build products, private notes, private agent files, or generated iconsets.
6. Commit with a clear release message.
7. Tag the commit with the matching `v<version>` tag.
8. Push `main` and the version tag.

## Current release

- `v0.2.1` — downloadable macOS zip release, README screenshots, and notification-free app surface.
- `v0.2.0` — multi-routine virtual-slot checkpoint with typed localization and routine settings.
- `v0.1.0` — first public source checkpoint.
