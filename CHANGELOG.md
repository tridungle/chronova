# Changelog

## Session 2 — 2026-04-03

### Added
- Photo detail/viewer screen with `photo_view` zoom/pan, swipe gallery, EXIF info sheet
- Photo deletion with confirmation dialog
- Edit trip (rename, update description) and delete trip with confirmation
- Search screen (full-text search across locations, notes, tags)
- Onboarding / welcome screen (4-page walkthrough, shown on first launch)
- Persistent theme preference via `shared_preferences`
- Tappable photos in vertical & horizontal timelines navigate to photo viewer
- Search button in timeline app bar
- `/search` route

### Fixed
- `video_export_screen.dart` — replaced non-existent `img.Animation()` with correct `GifEncoder.addFrame()` + `finish()` API for `image` package v4.x
- `video_export_screen.dart` — made `_polylineThickness` final (analyzer warning)

### Dependencies
- Added `shared_preferences`

---

## Session 1 — Initial Build

### Added
- Flutter project setup with Riverpod 2.0, flutter_map, Material 3
- Feature-first project structure (core/, data/, services/, features/)
- Data models: Photo, Trip, TimelineDay, JournalEntry with toMap/fromMap/copyWith
- SQLite database with trips, photos, journal_entries tables + indexes
- Repositories: PhotoRepository, TripRepository, JournalRepository (full CRUD)
- EXIF service: extracts DateTimeOriginal, GPS, camera model, dimensions
- Photo import service: multi-pick, EXIF processing, file copy, batch insert
- Location service: reverse geocoding (coords to city/country)
- 20+ Riverpod providers for trips, photos, timeline days, journals, UI state
- Timeline screen with vertical/horizontal toggle
- Vertical timeline: animated rail, photo collages (1-4+ grid), date/location/mood
- Horizontal timeline: PageView with date strip, thumbnails, location badges
- Map screen: flutter_map with circular markers, polyline (color picker + thickness), photo popup, dark/light tiles
- Video export: fly-along animation, RepaintBoundary frame capture, animated GIF encoding
- Trip management: list, create dialog, detail with timeline
- Journal editor: bottom sheet with 15 mood emojis, notes, 15 tag chips
- Settings: light/dark/system theme toggle, statistics, app info
- GoRouter with ShellRoute bottom nav + full-screen routes
- Full Material 3 light & dark themes with Poppins typography
- iOS/Android permissions configured
- README.md documentation
