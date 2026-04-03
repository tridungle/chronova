# Changelog

## Session 11 — 2026-04-03 (Bug Fixes & Import Enhancements)

### Fixed

- **DB migration still failing on cached singleton** — The `_onOpen` callback from Session 10 was insufficient because the `_database` singleton getter returns the cached instance without calling `openDatabase()` again, so `_onOpen`/`_onUpgrade` never fire after initial app launch. Added `_schemaVerified` flag and `_ensureSchema(Database)` method to `AppDatabase` that runs `PRAGMA table_info(photos)` on the first `database` access per session (even when cached) and adds the `file_hash` column + index if missing. Also made `PhotoRepository.existsByHash()` and `updateFileHash()` defensive with try/catch for `DatabaseException` — auto-adds the column and retries/returns gracefully.
- **Loading indicator not centered in import screen** — Replaced `Spacer()` + conditional widget layout with `Expanded(child: Center(child: SingleChildScrollView(...)))` pattern. Content is now always vertically centered in available space, with scroll support if content exceeds height.
- **Video export play/pause buttons overlapping with route error banner** — The `Positioned` overlay for play/pause buttons now uses a dynamic `top` value: `48` when the route error banner is visible, `12` otherwise.
- **Photos imported from trip detail not assigned to trip** — The "Import Photos" button on the trip detail screen navigated to `/import` without passing the `tripId`, so imported photos had `tripId: null` and never appeared in the trip. Fixed by passing `tripId` via `GoRouter.extra` to `PhotoImportScreen`, which now forwards it to all import service methods. The import result "Done" button also invalidates trip-specific providers (`tripPhotosProvider`, `tripTimelineDaysProvider`, `tripPhotoCountProvider`) so the trip detail refreshes.
- **"No Photos Selected" shown when all imports are duplicates** — Previously, when all selected photos were already in the library (duplicates), the result screen showed a generic "No Photos Selected" message. Now shows "All Duplicates" with an explanatory subtitle.

### Added

- **Camera import ("Take a Photo")** — New `takeAndImportPhoto()` method in `PhotoImportService` using `ImagePicker.pickImage(source: ImageSource.camera)`. Accessible from the import screen as a second button option.
- **File picker import ("Import from Files")** — Uses `file_picker` package (`FilePicker.platform.pickFiles()`) to allow importing photos from the device file system. Accessible from the import screen as a third button option.
- **Waypoint reorder persistence** — Video export screen now saves/restores waypoint order via `SharedPreferences`. The reorder sheet calls `_saveWaypointOrder()` after applying changes. On data load, `_applySavedOrder()` restores the saved order (discards if photo set has changed).
- **Assign existing photos to trip** — New bottom sheet on the trip detail screen (`_AssignPhotosSheet`) shows all unassigned photos in a selectable grid. Users can pick individual photos or "Select All", then assign them to the current trip via `PhotoRepository.assignToTrip()`. Accessible from the empty state and from a new "Add photos" popup menu in the app bar.
- **"Add photos" popup menu in trip detail app bar** — New `PopupMenuButton` with "Import New Photos" and "Assign Existing Photos" options, available even when the trip already has photos.

### Changed

- **Import screen refactored** — Extracted shared `_onProgress()`, `_postImport()`, and `_handleImportError()` helpers to reduce duplication across the three import paths (gallery, camera, files).
- **`_ImportPrompt` now shows 3 import options** — "Choose from Gallery" (primary filled button), "Take a Photo" (outlined), and "Import from Files" (outlined). Previously only showed the gallery option.
- **`PhotoImportScreen` accepts optional `tripId`** — When provided (e.g., from trip detail), all import paths forward it to the service so photos are created with `tripId` set.
- **`/import` route accepts `tripId` via `GoRouter.extra`** — Router extracts `tripId` from `state.uri.queryParameters` or `state.extra` and passes it to `PhotoImportScreen`.
- **Trip detail empty state improved** — Now shows two buttons: "Import Photos" (with `tripId`) and "Assign Existing Photos" (opens selection bottom sheet).

### Dependencies

- Added `file_picker: ^8.0.0` for file system import support.

---

## Session 10 — 2026-04-03 (DB Migration & Hero Tag Bug Fixes)

### Fixed

- **DB migration not running on existing installs** — Added `onOpen` safety callback to `AppDatabase` that checks for `file_hash` column via `PRAGMA table_info(photos)` and adds it if missing. Handles cases where `_onUpgrade` was skipped (e.g. hot restart with cached singleton). Also made `_onUpgrade` itself defensive with `CREATE INDEX IF NOT EXISTS`.
- **Hero tag conflict on multi-location days** — In `vertical_timeline.dart`, the `_PhotoCollage` and location sub-group thumbnail strips both used `Hero(tag: 'photo_${photo.id}')` for the same photos, causing a Flutter assertion error. Fixed by adding `heroTagPrefix` parameter to `_PhotoCollage` — uses `'collage'` prefix on multi-location days, `'photo'` on single-location days.

---

## Session 9 — 2026-04-03 (Duplicate Photo Detection on Import)

### Added

- **SHA-256 duplicate detection** — During photo import, each file's SHA-256 hash is computed and checked against both the current batch and existing photos in the database. Duplicate files are silently skipped and reported in the import result summary as "Duplicates skipped".
- `file_hash` column in `photos` table — Stores the SHA-256 hex digest of the original file content. Indexed for fast lookups.
- `file_hash` field on `Photo` model — Included in `toMap()`, `fromMap()`, and `copyWith()` with sentinel null-out support.
- `PhotoRepository.existsByHash(String)` — Checks if a photo with the given hash already exists (indexed query, limit 1).
- `PhotoRepository.updateFileHash(String id, String hash)` — Updates the hash for a single photo (used for backfilling).
- `PhotoImportService.computeFileHash(File)` — Public static method that computes SHA-256 via streaming (`sha256.bind(file.openRead())`), avoiding loading entire files into memory.
- `ImportResult.duplicateCount` field — Tracks how many files were skipped as duplicates during import.
- Import result screen now shows an orange "Duplicates skipped" row with `Icons.copy_all_rounded` when duplicates are detected.
- **Backfill support** — The existing "Re-scan EXIF Data" dialog in Settings now also computes and stores `file_hash` for any photo that has a null hash (i.e., photos imported before this feature).
- 6 new tests: `ImportResult.duplicateCount`, `computeFileHash` (SHA-256 correctness, same content = same hash, different content = different hash, 64-char hex format).

### Changed

- Database version bumped from 1 to 2 with migration (`ALTER TABLE photos ADD COLUMN file_hash TEXT` + index).
- `PhotoImportService._processFiles()` now computes hash before copying, checks for duplicates both within the batch (`batchHashes` set) and in the database, and skips duplicates without copying.
- Batch-internal duplicate tracking via `Set<String>` prevents importing the same file twice within a single import batch.

### Dependencies

- Added `crypto` package (promoted from transitive to direct dependency) for SHA-256 hashing.

### Tests

- Added 6 new tests for duplicate detection and file hashing.
- Total tests: **118** (up from 112).

---

## Session 8 — 2026-04-03 (Timeline Layout Refinements)

### Added

- **`LocationGroup.mood` and `LocationGroup.note` computed getters** — Each location sub-group now derives its own mood emoji and note from the first photo in the group that has a non-null value. This enables per-location mood/note display in both timeline views.
- 7 new tests for `LocationGroup.mood` and `LocationGroup.note` getters: empty list, no mood/note, first non-null value, skips empty strings.

### Changed

- **Vertical timeline: Date header above collage** — Refactored `_DayCard` to render the date + mood + count badge + optional location row ABOVE the photo collage instead of below it. Extracted `_buildDateHeader()` method. Removed `_buildInfoSection()` — its responsibilities split between the new date header (above collage) and inline note widget (below collage). Renamed `_buildMultiLocationSection()` → `_buildLocationSubGroups()` (no longer includes date header).
  - Multi-location layout: date header → collage → location sub-groups (each with label + mood, thumbnail strip, note)
  - Single-location layout: date header (with location) → collage → note preview
- **Horizontal timeline: Fixed RenderFlex overflow** — Wrapped multi-location sub-groups in `Expanded(flex: 2, child: SingleChildScrollView(...))` instead of spreading them directly into the fixed-height `Column`. Gives bounded height with internal scrolling. Day-level mood/note now only shown in single-location mode; multi-location mode shows per-group mood/note.
- Updated `makePhoto` test helper to accept optional `mood` and `note` parameters.

### Tests

- Added 7 new unit tests for `LocationGroup` computed getters.
- Total tests: **112** (up from 105).

---

## Session 7 — 2026-04-03 (Video Export Bug Fixes & Timeline Location Sub-grouping)

### Fixed

- **Fix #1: Polyline tip / transport icon desync** — Transport icon and polyline tip were computed independently, causing the icon to visually detach from the path end. Added `_currentIconPosition` state field as single source of truth — `_onAnimationTick()` computes position once via `_positionAtDistance()` and both `_revealedPath` and the icon `Marker` reference it. Removed redundant `(_useEasing ? 1.0 : 1.0)` expression.
- **Fix #3: Camera too zoomed in** — `_mapController.move(position, _zoomLevel)` locked camera directly on the icon with fixed zoom. Replaced with `_fitCameraToProgress()` that builds a bounding box from the current position + nearby waypoints + 5% lookahead, using `_mapController.fitCamera(CameraFit.bounds(...))` with 60px padding and maxZoom 15 for contextual framing.
- **Fix #4: Cannot pan/zoom during preview** — `_onAnimationTick()` called `_mapController.move()` every frame, overriding all user gestures. Added `_cameraFollowMode` flag; camera updates only when follow mode is active. `MapOptions.onPositionChanged` detects `hasGesture == true` and disables follow. A re-center FAB (`Icons.my_location_rounded`) appears when follow mode is off.

### Added

- **Waypoint reorder sheet** (Fix #2) — `_showReorderSheet()` presents a `DraggableScrollableSheet` with `ReorderableListView` showing photo thumbnails, location names, and dates. Users can drag-to-reorder stops, then Apply (re-fetches route) or Cancel. Accessible via "Reorder Waypoints" button in settings panel.
- **Timeline location sub-grouping** — Photos within the same day but at different locations are now visually separated into sub-groups in both vertical and horizontal timeline views:
  - `LocationGroup` class (`timeline_day.dart`) with `label`, `photos`, `isUnknown`, `primaryPhoto`
  - `TimelineDay.groupByLocation()` static method groups photos by `locationName` (or "Unknown Location" fallback)
  - `locationGroups` field on `TimelineDay` (nullable private `_locationGroups` with null-safe getter for hot-reload safety)
  - `hasMultipleLocations` getter
  - Vertical timeline: location pin headers + per-group photo sections with dividers
  - Horizontal timeline: "N locations" badge on hero photo + location-labeled thumbnail sections
- 12 new tests for `LocationGroup`, `groupByLocation()`, `hasMultipleLocations`, and edge cases (all photos same location, mixed locations, no location name, single photo)

### Changed

- Both `timelineDaysProvider` and `tripTimelineDaysProvider` now call `TimelineDay.groupByLocation(photos)` and pass the result when constructing `TimelineDay` instances.
- Vertical timeline `_DayCard` refactored: extracted `_buildInfoSection()` and `_buildLocationSubGroups()` methods.
- Horizontal timeline `_HorizontalDayCard` refactored: extracted `_buildThumbnailStrip()` and `_buildLocationThumbnailSections()` methods.

### Tests

- Added 12 new unit tests for timeline location sub-grouping.
- Total tests: **105** (up from 93).

---

## Session 6 — 2026-04-03 (Video Export Routing Enhancement)

### Added

- **Real road-following routes** — Video export now fetches actual road geometry from the OSRM (Open Source Routing Machine) public API instead of drawing straight lines between photo waypoints. Supports batching for trips with 80+ waypoints.
- **Transport mode selector** — Users can choose between Car, Walking, Cycling, and Plane modes. Car/Walking/Cycling fetch real routes from OSRM; Plane uses straight lines with intermediate interpolation points every ~50km for smooth animation.
- **Progressive path reveal** — The polyline is drawn progressively as the transport icon passes over it, creating a "drawing the path" visual effect during preview and export.
- **Transport icon with heading** — An animated circular marker with the selected transport icon moves along the route, rotating based on the bearing/heading between consecutive path points.
- **Ghost path preview** — When not animating, the full planned route is shown as a faint 20% opacity line so users can see the complete route before starting.
- **Route loading overlay** — Semi-transparent overlay with spinner and "Calculating route..." text while OSRM API call is in progress.
- **Route error banner** — Orange warning bar with "Route unavailable — using straight lines" message and Retry button when OSRM fails.
- **Uniform-speed animation** — Animation now uses cumulative distance along the routed path (with binary search interpolation) for consistent travel speed, replacing the old segment-based approach that had inconsistent speeds for segments of different lengths.
- **Route distance display** — Estimated output info now shows total route distance in km alongside duration and frame count.
- `RoutingService` class (`lib/services/routing_service.dart`) — OSRM API integration with batching, plane straight-line fallback, and graceful error handling.
- `TransportMode` enum — Car, Walking, Cycling, Plane with icons and OSRM profile names.
- `routingServiceProvider` in `app_providers.dart`.

### Changed

- **Video export screen fully rewritten** — Replaced original segment-based interpolation with distance-based uniform-speed animation. Removed unused `_showLocationLabels` toggle (had no implementation). Now uses `AppConstants.defaultAnimationSpeedSec` for initial speed value.
- Extracted map preview, settings panel, and empty state into separate builder methods for readability.

### Dependencies

- Added `http` package (promoted from transitive to direct dependency) for OSRM API calls.

### Tests

- Added 16 new unit tests for `RoutingService` and `TransportMode`:
  - TransportMode: enum values, properties, labels, icons, OSRM profile names
  - RoutingService: empty/single input handling, plane mode interpolation (long/short distances, multi-waypoint), road-based mode fallback (car/walking/cycling with proximity checks)
- Total tests: **93** (up from 77).

---

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
