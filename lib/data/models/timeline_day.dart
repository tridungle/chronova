import 'photo.dart';

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

  /// The primary photo for this day (first photo with location, or just first)
  Photo get primaryPhoto =>
      photos.firstWhere((p) => p.hasLocation, orElse: () => photos.first);

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
    String? tripId,
    String? photoId,
    DateTime? date,
    String? content,
    String? mood,
    String? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      photoId: photoId ?? this.photoId,
      date: date ?? this.date,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
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
      date: DateTime.parse(map['date'] as String),
      content: map['content'] as String,
      mood: map['mood'] as String?,
      tags: map['tags'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
