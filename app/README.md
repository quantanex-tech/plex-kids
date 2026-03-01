# Plex Kids (Flutter app)

## Run locally
From repo root:

### Linux/macOS (repo-local Flutter SDK)
```bash
cd app
../scripts/flutter.sh pub get
../scripts/flutter.sh run
```

### Windows (system Flutter)
```powershell
cd app
flutter pub get
flutter run
```

## CI builds
A debug APK is built on every push to `main` via GitHub Actions.
Download from Actions → latest run → Artifacts → `plex-kids-debug-apk`.
