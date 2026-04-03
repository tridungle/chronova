import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../services/exif_service.dart';
import '../../services/location_service.dart';
import '../../services/photo_import_service.dart';

// ─── Service Providers ──────────────────────────────────────────

final exifServiceProvider = Provider<ExifService>((ref) => ExifService());

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final photoImportServiceProvider = Provider<PhotoImportService>((ref) {
  return PhotoImportService(
    exifService: ref.watch(exifServiceProvider),
    photoRepository: ref.watch(photoRepositoryProvider),
  );
});

// ─── Repository Providers ───────────────────────────────────────

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(),
);

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(),
);

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(),
);

// ─── Trip Providers ─────────────────────────────────────────────

/// All trips, sorted by start date descending
final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.getAll();
});

/// Single trip by ID
final tripProvider = FutureProvider.family<Trip?, String>((ref, id) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.getById(id);
});

// ─── Photo Providers ────────────────────────────────────────────

/// All photos
final allPhotosProvider = FutureProvider<List<Photo>>((ref) async {
  final repo = ref.watch(photoRepositoryProvider);
  return repo.getAll();
});

/// Photos for a specific trip
final tripPhotosProvider = FutureProvider.family<List<Photo>, String>((
  ref,
  tripId,
) async {
  final repo = ref.watch(photoRepositoryProvider);
  return repo.getByTripId(tripId);
});

/// Photos with GPS coordinates (for map view)
final geoPhotosProvider = FutureProvider<List<Photo>>((ref) async {
  final repo = ref.watch(photoRepositoryProvider);
  return repo.getWithLocation();
});

/// Unassigned photos
final unassignedPhotosProvider = FutureProvider<List<Photo>>((ref) async {
  final repo = ref.watch(photoRepositoryProvider);
  return repo.getUnassigned();
});

/// Total photo count
final photoCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(photoRepositoryProvider);
  return repo.count();
});

// ─── Timeline Providers ─────────────────────────────────────────

/// Groups all photos by date into TimelineDay objects
final timelineDaysProvider = FutureProvider<List<TimelineDay>>((ref) async {
  final repo = ref.watch(photoRepositoryProvider);
  final dateKeys = await repo.getDistinctDates();

  final days = <TimelineDay>[];
  for (final dateKey in dateKeys) {
    final photos = await repo.getByDate(dateKey);
    if (photos.isEmpty) continue;

    // Determine primary location
    final locPhoto = photos.firstWhere(
      (p) => p.locationName != null,
      orElse: () => photos.first,
    );

    days.add(
      TimelineDay(
        date: DateTime.parse(dateKey),
        locationName: locPhoto.locationName,
        note: photos.first.note,
        mood: photos.first.mood,
        photos: photos,
      ),
    );
  }

  return days;
});

/// Timeline days for a specific trip
final tripTimelineDaysProvider =
    FutureProvider.family<List<TimelineDay>, String>((ref, tripId) async {
      final repo = ref.watch(photoRepositoryProvider);
      final photos = await repo.getByTripId(tripId);

      // Group by date
      final grouped = <String, List<Photo>>{};
      for (final photo in photos) {
        final key =
            photo.dateTaken?.toIso8601String().substring(0, 10) ?? 'unknown';
        grouped.putIfAbsent(key, () => []).add(photo);
      }

      final days = <TimelineDay>[];
      for (final entry in grouped.entries) {
        if (entry.key == 'unknown') continue;
        final datePhotos = entry.value;
        final locPhoto = datePhotos.firstWhere(
          (p) => p.locationName != null,
          orElse: () => datePhotos.first,
        );

        days.add(
          TimelineDay(
            date: DateTime.parse(entry.key),
            locationName: locPhoto.locationName,
            note: datePhotos.first.note,
            mood: datePhotos.first.mood,
            photos: datePhotos,
          ),
        );
      }

      days.sort((a, b) => a.date.compareTo(b.date));
      return days;
    });

// ─── Journal Providers ──────────────────────────────────────────

final journalEntriesProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final repo = ref.watch(journalRepositoryProvider);
  return repo.getAll();
});

final tripJournalEntriesProvider =
    FutureProvider.family<List<JournalEntry>, String>((ref, tripId) async {
      final repo = ref.watch(journalRepositoryProvider);
      return repo.getByTripId(tripId);
    });

// ─── UI State Providers ─────────────────────────────────────────

/// Current theme mode (system, light, dark)
final themeModeProvider = StateProvider<int>(
  (ref) => 0,
); // 0=system, 1=light, 2=dark

/// Timeline view mode: true = vertical, false = horizontal
final timelineVerticalProvider = StateProvider<bool>((ref) => true);

/// Currently selected trip ID (null = all photos)
final selectedTripIdProvider = StateProvider<String?>((ref) => null);

/// Import progress state
final importProgressProvider = StateProvider<(int current, int total)?>(
  (ref) => null,
);

/// Whether the app is currently importing
final isImportingProvider = StateProvider<bool>((ref) => false);

/// Bottom nav index
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
