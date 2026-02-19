# Architecture (Draft)

## Tech stack
- Flutter (Dart)
- UI prototyping/building: FlutterFlow (export + integrate)

## App modules
- `plex/` — Plex auth + API client
- `domain/` — models (Library, Show, Episode, Movie, User)
- `ui/` — screens + components (FlutterFlow + custom widgets)
- `player/` — playback abstraction
- `storage/` — cache + secure token storage

## Suggested libraries
- State management: Riverpod
- Networking: Dio
- Caching: Isar or Hive
- Secure storage: flutter_secure_storage
- Video: video_player (evaluate better_player if needed)

## Key architectural decisions
- Library-level filtering for v1
- Plex user profiles are the source of identity
- Parent-gated settings area

## Open questions
- Preferred Plex auth flow: PIN login vs web OAuth
- Subtitle and audio track controls for kids UI
- Metrics/logging approach (local only?)
