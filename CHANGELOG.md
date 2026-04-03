# Changelog

## Session 5 — 2026-04-03 (Runtime Bug Fixes & Regression Tests)

### Fixed (Critical)

- **EXIF date parsing completely broken** — `replaceFirst(RegExp(...), r'$1-$2-$3')` inserted literal `$1-$2-$3` instead of backreferences. Changed to `replaceFirstMapped` so EXIF dates (e.g. `"2024:01:15 14:30:00"`) are correctly parsed. All previously imported photos had null `dateTaken` due to this bug.
- **Map tile DNS failures** — Added `errorImage` (transparent 1x1 PNG via `MemoryImage`) and `evictErrorTileStrategy: EvictErrorTileStrategy.dispose` to both `TileLayer` instances in `map_screen.dart` and `video_export_screen.dart`. Gracefully handles offline/DNS errors instead of spamming exceptions.

### Improved

- Extracted `ExifService.parseExifDateString()` as a `@visibleForTesting` static method for direct unit testing of EXIF date parsing logic.

### Tests

- Added 8 new unit tests for `ExifService.parseExifDateString()`: standard format, various dates, midnight, null/empty/unparseable inputs, date-only, and a regression test guarding against the `replaceFirst` backreference bug.
- Total tests: **77** (up from 69).

### Lint Fixes

- Removed unnecessary `dart:typed_data` imports from `map_screen.dart` and `video_export_screen.dart` (already provided by `flutter/services.dart`).
- Renamed `_makePhoto` to `makePhoto` in `timeline_day_test.dart` (no leading underscores for local identifiers).

### Note

- Existing photos in the database that were imported before this fix will have null `dateTaken`. Use **Settings > Re-scan EXIF Data** to refresh metadata for all existing photos without re-importing.

### Added

- **Re-scan EXIF Data** feature in Settings — re-reads EXIF metadata (date, GPS, camera) from all photo files and updates the database. Shows progress bar and summary (updated/skipped/errors). Automatically refreshes all providers on completion.
- `PhotoRepository.updateExifFields()` — targeted update of EXIF-related columns for a single photo.

---

## Session 4 — 2026-04-03 (Polish, Features, Tests)

### Phase 2: Polish & UX

- Created reusable `ErrorRetryWidget` — replaced bare error states in 5 screens
- Added haptic feedback across all 12+ screens (imports, taps, navigation, actions)
- Added `RefreshIndicator` pull-to-refresh to Timeline, Trips, TripDetail screens
- Created `ShimmerLoading` widget + `SkeletonLoaders` (timeline, trip list)
- Added CTA "Import Photos" buttons to empty states in Map, TripDetail, VideoExport
- Added missing Hero animations for photo transitions
- Added try/catch to journal editor save, replaced `Future.delayed` with `Timer` debounce

### Phase 3: New Features

- **Overlay fade animations** — `AnimatedOpacity` + `IgnorePointer` for photo detail overlays
- **Map popup enhancement** — `AnimatedSlide`/`AnimatedOpacity` popup with "View" button + Hero transition
- **Photo reordering** — Drag-to-reorder photos within trips via `ReorderablePhotoGrid` widget with `updateSortOrders` repository method
- **Video export improvements** — Configurable zoom (6-16), smoothness (5/10/15/20 fps), easing curves, estimated duration display

### Phase 4: Tests

- 69 unit tests: Photo, Trip, TimelineDay, JournalEntry, ExifData models + ExifService
- `flutter analyze` clean, `flutter test` all passing

---

## Session 3 — 2026-04-03 (Comprehensive Bug Fix Sweep)

### Fixed (Critical — 7 issues)

- SQLite `as double?` cast crashes → Fixed with `(map['x'] as num?)?.toDouble()`
- Database race condition → Fixed with `Completer` pattern
- Division by zero in EXIF GPS → Fixed with `denominator == 0` guards
- `setState()` after dispose → Fixed with `if (!mounted) return` guards
- Photo detail mutating `widget.photos` + RangeError → Fixed with local copy + PageController recreation
- `MapController` not disposed → Fixed with `dispose()` override
- `LatLngBounds.fromPoints` crashes on empty list → Fixed with empty guard

### Fixed (Warning — 10 issues)

- `copyWith` cannot null out fields → Fixed with `_absent` sentinel pattern
- Journal editor duplicates → Fixed with upsert via `getByPhotoId`
- `TimelineDay.primaryPhoto` crashes on empty → Fixed nullable `Photo?`
- `DateTime.parse` FormatException → Fixed with `DateTime.tryParse`
- `FutureBuilder` in ConsumerWidget → Fixed with `tripPhotoCountProvider`
- `TextEditingController` leak in dialogs → Fixed with `.then((_) => controller.dispose())`
- Video export stale data → Fixed: only update when not animating/exporting
- Map button in photo detail → Fixed with `GoRouter.of(context).go('/map')`
- Mixed `Navigator.push`/GoRouter → Accepted as-is (valid for complex params)
- `_colorNames` count noted, low risk

### Fixed (Minor — 5 issues)

- Animation delays capped at max values
- Indicator dots limited to 10 → Shows "x / y" for >10
- Hardcoded version → Added `AppConstants.appVersion`
- Empty onTap → Now opens `showAboutDialog`
- `MediaQuery.of(context)` → Replaced with `MediaQuery.sizeOf`/`viewInsetsOf`/`paddingOf`

---

## Session 2 — 2026-04-03 (Enhancements)

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
