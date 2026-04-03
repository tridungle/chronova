# Chronova

**Your Life, Beautifully Mapped**

A personal photo timeline and journey app built with Flutter. Chronova automatically reads EXIF data (date + GPS coordinates) from photos, creates a beautiful timeline with journal notes, displays everything on a map, and can export a cinematic travel video similar to TravelBoast or Polarsteps.

## Features

### Photo Import & EXIF Processing

- Select multiple photos from the device gallery
- Automatically extract `DateTimeOriginal` and GPS coordinates (latitude, longitude, altitude) from EXIF metadata
- Reverse geocode GPS coordinates to human-readable location names (city, country)
- Copy photos to app storage with batch database insert and progress UI
- Extract camera model, image dimensions, and file size

### Timeline View

- **Vertical Timeline** — Rail-style connector with dots, photo collages (1 to 4+ grid layout), date, location, mood, and journal notes
- **Horizontal Timeline** — Swipeable PageView cards with a date strip selector, photo thumbnails, and location badges
- Toggle between views with a single tap
- Staggered entrance animations for a polished feel
- Group photos by date or by user-created Trips

### Map View

- Display all photo locations as circular thumbnail markers on the map
- Draw a polyline connecting points in chronological order
- Customizable polyline color (6 options) and thickness via slider
- Tap a marker to show a photo popup with date, location, and note
- Fit-to-bounds button to zoom to all markers
- Automatic dark/light map tiles matching app theme (Carto Voyager / Carto Dark)

### Cinematic Video Export

- Fly-along animation that smoothly moves the camera from one marker to the next
- Photo popups appear at each waypoint during the animation
- Adjustable animation speed (1-8 seconds per segment)
- Customizable path color
- Toggle photo popups and location labels
- Preview playback with play/pause controls
- Export and share via the system share sheet

### Trip Management

- Create named trips to group photos by destination or journey
- View trip-specific timeline with dedicated photo count
- Trip list with cover photo, date range, and description

### Journal & Notes

- Add journal notes to any photo or day via a bottom sheet editor
- Mood selector with 15 emoji options
- Tag system with 15 built-in categories (Travel, Food, Nature, City, etc.)
- Notes saved to both the photo record and a dedicated journal entries table

### Settings

- Light, Dark, and System theme modes
- Material 3 design with Poppins typography
- Photo and trip statistics dashboard
- App version and info

## Tech Stack

| Area | Choice |
|------|--------|
| Framework | Flutter 3.29+ / Dart 3.7+ |
| State Management | Riverpod 2 |
| Database | sqflite (SQLite) — offline-first |
| Map | flutter_map + OpenStreetMap / Carto tiles |
| Navigation | GoRouter with ShellRoute |
| EXIF Parsing | `exif` package |
| Animations | flutter_animate |
| UI | Material 3, Poppins font, dark/light themes |
| Video | ffmpeg_kit_flutter (rendering pipeline) |
| Geocoding | `geocoding` package |
| Platforms | Android & iOS |

## Project Structure

```text
lib/
  main.dart                              # App entry point with ProviderScope
  core/
    constants/app_constants.dart         # Map URLs, moods, tags, video settings
    extensions/extensions.dart           # DateTime, BuildContext, String, List extensions
    providers/app_providers.dart         # All Riverpod providers
    theme/
      app_theme.dart                     # Material 3 light & dark themes
      app_text_styles.dart               # Shared typography
    utils/
      app_router.dart                    # GoRouter with bottom nav shell
  data/
    database/app_database.dart           # SQLite schema and migrations
    models/
      photo.dart                         # Photo model with EXIF fields
      trip.dart                          # Trip model
      timeline_day.dart                  # TimelineDay & JournalEntry models
      models.dart                        # Barrel export
    repositories/
      photo_repository.dart              # Photo CRUD, search, grouping, batch ops
      trip_repository.dart               # Trip CRUD with photo count
      journal_repository.dart            # Journal entry CRUD
      repositories.dart                  # Barrel export
  services/
    exif_service.dart                    # EXIF extraction (date, GPS, camera)
    photo_import_service.dart            # Gallery pick, process, save pipeline
    location_service.dart                # Reverse geocoding
  features/
    home/
      app_shell.dart                     # Bottom navigation with animated bar
      home_screen.dart                   # Home placeholder
    timeline/
      timeline_screen.dart               # Vertical/horizontal toggle screen
      widgets/
        vertical_timeline.dart           # Rail timeline with collages
        horizontal_timeline.dart         # PageView card timeline
    map/
      map_screen.dart                    # Map with markers, polyline, popup
    trips/
      trips_screen.dart                  # Trip list with create dialog
      trip_detail_screen.dart            # Trip-specific timeline
    photo_import/
      photo_import_screen.dart           # Import flow with progress & results
    video_export/
      video_export_screen.dart           # Fly-along preview & export
    journal/
      journal_editor.dart                # Bottom sheet mood/tags/notes editor
    settings/
      settings_screen.dart               # Theme, stats, about
```

## Getting Started

### Prerequisites

- Flutter 3.24 or later
- Dart 3.4 or later
- Xcode (for iOS)
- Android Studio (for Android)

### Installation

```bash
# Clone and enter the project
cd chronova

# Install dependencies
flutter pub get

# iOS only: install CocoaPods
cd ios && pod install && cd ..

# Run the app
flutter run

# OR Run with simulator ID
flutter run -d 90DA1D5E-39C9-4773-BE8A-DCE7242B4E3B 2>&1
```

### Android Permissions

The following permissions are configured in `AndroidManifest.xml`:

- `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` — photo access
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` — GPS & geocoding
- `INTERNET` — map tiles and geocoding API

### iOS Permissions

The following usage descriptions are configured in `Info.plist`:

- `NSPhotoLibraryUsageDescription` — photo library access
- `NSPhotoLibraryAddUsageDescription` — save exported videos
- `NSLocationWhenInUseUsageDescription` — location tagging
- `NSCameraUsageDescription` — camera capture
- `NSMicrophoneUsageDescription` — video recording

## Database Schema

Three tables with indexed columns for fast queries:

- **trips** — id, name, description, cover_photo_path, start_date, end_date, color
- **photos** — id, file_path, trip_id, date_taken, latitude, longitude, altitude, location_name, camera_model, note, mood, tags, sort_order
- **journal_entries** — id, trip_id, photo_id, date, content, mood, tags

## License

This project is for personal/educational use.
