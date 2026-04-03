import 'photo.dart';

/// Sentinel value used by copyWith to distinguish "not provided" from "null".
const _absent = Object();

/// Represents a group of photos for a single day in the timeline.
class TimelineDay {
  final DateTime date;
  final String? locationName;
  final String? note;
  final String? mood;
  final List<Photo> photos;

  const TimelineDay({
    required this.date,
    this.locationName,
    this.note,
    this.mood,
    required this.photos,
  });

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
