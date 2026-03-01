# kids-plex

A kid-friendly Plex client for Android (phone + tablet): a YouTube Kids-style UI backed by your Plex server.

## Status
Early planning / requirements.

## Docs
- `docs/requirements.md`
- `docs/architecture.md`
- `docs/milestones.md`

## Development
Flutter (UI initially prototyped in FlutterFlow; core app in Flutter/Dart).

### Flutter SDK
This repo uses a **local Flutter SDK** at `./.flutter/` (ignored by git) for Linux dev on this machine.

Run via:
- `./scripts/flutter.sh doctor`
- `cd app && ../scripts/flutter.sh run`

### CI: Android APK builds
GitHub Actions builds a **debug APK** on every push to `main`.
- Artifact name: `plex-kids-debug-apk`
- File: `app-debug.apk`

This is intended for easy sideload testing.

### Releases (recommended for Obtainium)
There is a manual workflow to publish a GitHub Release with an attached debug APK.

How to run:
- GitHub → Actions → **Release APK** → Run workflow
- Enter a tag like `v0.0.1` (pre-release default: true)

The release will include:
- `plex-kids-<tag>-debug.apk`
