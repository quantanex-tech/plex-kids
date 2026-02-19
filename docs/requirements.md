# Kids Plex Client — Requirements

## Goal
Build a **kid-friendly Plex client** for **Android (mobile + tablet)** that feels like YouTube Kids, but streams content from a Plex server.

## Non-goals (v1)
- App store distribution (Play Store) is not required initially.
- Offline downloads are **out of scope for MVP**, but are a **top v2 priority**.

## Target platforms
- Android phone + tablet (primary)

## Users & safety model
- Use **Plex users / managed users** for profiles (no separate in-app kid accounts in v1).
- Parent/admin access should be gated (PIN or similar) before showing settings or server/account details.

## Content source and filtering
- Content is sourced from **Plex Libraries**.
- MVP supports **TV + Movies libraries only**.
- For v1, filtering is at the library level (only selected libraries are visible).
  - Future: per-show allow/block lists, Collections/Labels, ratings filters.

## Core user stories
1. As a parent, I can sign in to Plex and pick a Plex user so my kid sees only their profile.
2. As a parent, I can choose which Plex libraries are visible in the kid UI.
3. As a kid, I see a simple home screen with big artwork and minimal text.
4. As a kid, I can tap a show/movie and play it with minimal friction.
5. As a kid, I can continue watching where I left off.

## MVP feature set
### Onboarding
- Plex sign-in via **web auth** (preferred) and server selection
- Select Plex user / managed user
- Parent gate to access settings

### Home
- Continue Watching
- Recently Added (from allowed libraries)
- Library tiles (big, simple)

### Browsing
- Movies: grid
- Shows: show → seasons → episodes
- Episode details: play/resume

### Search
- Search across **allowed libraries** (not the primary UX focus)

### Playback
- Play video streams from Plex
- Resume playback
- **Miniplayer overlay** with browse rails for quick switching to other shows/movies
- Basic subtitle toggle (optional for MVP; parent-locked later)

### Settings (parent-gated)
- Switch Plex user
- Choose allowed libraries
- Log out
- Basic diagnostics (app version, server name) — keep minimal

## Important v2 features
- Offline downloads + storage management
- Time limits / schedules
- Stronger content controls (Collections/Labels/ratings)
- Multi-device UX (Android TV / Fire TV)

## UX principles
- Large touch targets
- Minimal navigation depth
- Artwork-first, text-second
- Accidental-exit resistance (confirmations / parent gate)
- Fast startup and fast “play” path
