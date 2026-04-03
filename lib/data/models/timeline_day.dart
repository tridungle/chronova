import 'photo.dart';

/// Sentinel value used by copyWith to distinguish "not provided" from "null".
const _absent = Object();

/// A sub-group of photos within a single day, grouped by location name.
///
/// When multiple photos share the same date but different locations, each
/// distinct location becomes a [LocationGroup]. Photos without a location
/// are grouped under [unknownLabel].
class LocationGroup {
  /// Display label (location name or fallback).
  final String label;

  /// Photos at this location on this day.
  final List<Photo> photos;

  /// Whether this is a real location or the fallback "Unknown Location" group.
  final bool isUnknown;

  const LocationGroup({
    required this.label,
    required this.photos,
    this.isUnknown = false,
  });

  /// Default label for photos without a location name.
  static const String unknownLabel = 'Unknown Location';

  /// The primary photo for this location group.
  Photo? get primaryPhoto {
    if (photos.isEmpty) return null;
    return photos.firstWhere((p) => p.hasLocation, orElse: () => photos.first);
  }

  /// The mood for this location group — returns the first non-null mood
  /// found among the photos, or null if none have a mood.
  String? get mood {
    for (final photo in photos) {
      if (photo.mood != null) return photo.mood;
    }
    return null;
  }

  /// The note for this location group — returns the first non-null, non-empty
  /// note found among the photos, or null if none have a note.
  String? get note {
    for (final photo in photos) {
      if (photo.note != null && photo.note!.isNotEmpty) return photo.note;
    }
    return null;
  }
}

/// Represents a group of photos for a single day in the timeline.
class TimelineDay {
  final DateTime date;
  final String? locationName;
  final String? note;
  final String? mood;
  final List<Photo> photos;

  /// Photos sub-grouped by location within this day.
  /// Populated by the provider layer. If empty/null, the UI falls back to
  /// showing all [photos] in a single group.
  ///
  /// Stored as nullable internally to survive hot-reload of stale instances
  /// that were constructed before this field existed.
  final List<LocationGroup>? _locationGroups;

  /// Location groups, guaranteed non-null. Returns an empty list if the
  /// field was never populated (e.g. stale hot-reload instance).
  List<LocationGroup> get locationGroups => _locationGroups ?? const [];

  const TimelineDay({
    required this.date,
    this.locationName,
    this.note,
    this.mood,
    required this.photos,
    List<LocationGroup>? locationGroups,
  }) : _locationGroups = locationGroups;

  /// The primary photo for this day (first photo with location, or just first).
  /// Returns null only if [photos] is empty (should not happen in practice).
  Photo? get primaryPhoto {
    if (photos.isEmpty) return null;
    return photos.firstWhere((p) => p.hasLocation, orElse: () => photos.first);
  }

  /// Number of photos with GPS coordinates
  int get photosWithLocation => photos.where((p) => p.hasLocation).length;

  /// All unique location names for this day
  List<String> get locations =>
      photos
          .where((p) => p.locationName != null)
          .map((p) => p.locationName!)
          .toSet()
          .toList();

  /// Whether this day has multiple distinct locations (i.e. sub-groups matter).
  bool get hasMultipleLocations => locationGroups.length > 1;

  /// Build [LocationGroup]s from a flat list of photos.
  ///
  /// Groups photos by [Photo.locationName]. Photos without a location name
  /// are placed under [LocationGroup.unknownLabel]. Groups are ordered:
  /// named locations first (in the order they appear), then the unknown group.
  static List<LocationGroup> groupByLocation(List<Photo> photos) {
    final map = <String, List<Photo>>{};
    for (final photo in photos) {
      final key = photo.locationName ?? LocationGroup.unknownLabel;
      map.putIfAbsent(key, () => []).add(photo);
    }

    final groups = <LocationGroup>[];
    LocationGroup? unknownGroup;

    for (final entry in map.entries) {
      final isUnknown = entry.key == LocationGroup.unknownLabel;
      final group = LocationGroup(
        label: entry.key,
        photos: entry.value,
        isUnknown: isUnknown,
      );
      if (isUnknown) {
        unknownGroup = group;
      } else {
        groups.add(group);
      }
    }

    // Unknown group goes last
    if (unknownGroup != null) {
      groups.add(unknownGroup);
    }

    return groups;
  }
}

/// Represents a journal entry (can be standalone or tied to a photo/day).
class JournalEntry {
  final String id;
  final String? tripId;
  final String? photoId;
  final DateTime date;
  final String content;
  final String? mood;
  final String? tags; // comma-separated
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    this.tripId,
    this.photoId,
    required this.date,
    required this.content,
    this.mood,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get tagList =>
      tags?.split(',').where((t) => t.trim().isNotEmpty).toList() ?? [];

  JournalEntry copyWith({
    String? id,
    Object? tripId = _absent,
    Object? photoId = _absent,
    DateTime? date,
    String? content,
    Object? mood = _absent,
    Object? tags = _absent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      tripId: identical(tripId, _absent) ? this.tripId : tripId as String?,
      photoId: identical(photoId, _absent) ? this.photoId : photoId as String?,
      date: date ?? this.date,
      content: content ?? this.content,
      mood: identical(mood, _absent) ? this.mood : mood as String?,
      tags: identical(tags, _absent) ? this.tags : tags as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'photo_id': photoId,
      'date': date.toIso8601String(),
      'content': content,
      'mood': mood,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      tripId: map['trip_id'] as String?,
      photoId: map['photo_id'] as String?,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      content: map['content'] as String,
      mood: map['mood'] as String?,
      tags: map['tags'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
