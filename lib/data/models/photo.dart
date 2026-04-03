import '../../core/utils/photo_path_resolver.dart';

/// Sentinel value used by copyWith to distinguish "not provided" from "null".
const _absent = Object();

/// Data model representing a Photo with EXIF metadata.
class Photo {
  final String id;
  final String filePath;
  final String? thumbnailPath;
  final String? tripId;
  final DateTime? dateTaken;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final String? locationName; // reverse geocoded
  final String? cameraModel;
  final int? width;
  final int? height;
  final int? fileSize; // bytes
  final String? fileHash; // SHA-256 of file content for duplicate detection
  final String? note;
  final String? mood;
  final String? tags; // comma-separated
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Photo({
    required this.id,
    required this.filePath,
    this.thumbnailPath,
    this.tripId,
    this.dateTaken,
    this.latitude,
    this.longitude,
    this.altitude,
    this.locationName,
    this.cameraModel,
    this.width,
    this.height,
    this.fileSize,
    this.fileHash,
    this.note,
    this.mood,
    this.tags,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this photo has valid GPS coordinates
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether this photo has a date taken
  bool get hasDate => dateTaken != null;

  /// Resolve [filePath] (which may be relative or a stale absolute path)
  /// to a valid absolute path under the current app documents directory.
  String get resolvedFilePath => PhotoPathResolver.instance.resolve(filePath);

  /// Get list of tags
  List<String> get tagList =>
      tags?.split(',').where((t) => t.trim().isNotEmpty).toList() ?? [];

  /// Copy with support for explicitly setting nullable fields to null.
  /// Use the sentinel [_absent] to distinguish "not provided" from "set to null".
  Photo copyWith({
    String? id,
    String? filePath,
    Object? thumbnailPath = _absent,
    Object? tripId = _absent,
    Object? dateTaken = _absent,
    Object? latitude = _absent,
    Object? longitude = _absent,
    Object? altitude = _absent,
    Object? locationName = _absent,
    Object? cameraModel = _absent,
    int? width,
    int? height,
    int? fileSize,
    Object? fileHash = _absent,
    Object? note = _absent,
    Object? mood = _absent,
    Object? tags = _absent,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Photo(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      thumbnailPath:
          identical(thumbnailPath, _absent)
              ? this.thumbnailPath
              : thumbnailPath as String?,
      tripId: identical(tripId, _absent) ? this.tripId : tripId as String?,
      dateTaken:
          identical(dateTaken, _absent)
              ? this.dateTaken
              : dateTaken as DateTime?,
      latitude:
          identical(latitude, _absent) ? this.latitude : latitude as double?,
      longitude:
          identical(longitude, _absent) ? this.longitude : longitude as double?,
      altitude:
          identical(altitude, _absent) ? this.altitude : altitude as double?,
      locationName:
          identical(locationName, _absent)
              ? this.locationName
              : locationName as String?,
      cameraModel:
          identical(cameraModel, _absent)
              ? this.cameraModel
              : cameraModel as String?,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      fileHash:
          identical(fileHash, _absent) ? this.fileHash : fileHash as String?,
      note: identical(note, _absent) ? this.note : note as String?,
      mood: identical(mood, _absent) ? this.mood : mood as String?,
      tags: identical(tags, _absent) ? this.tags : tags as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'thumbnail_path': thumbnailPath,
      'trip_id': tripId,
      'date_taken': dateTaken?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'location_name': locationName,
      'camera_model': cameraModel,
      'width': width,
      'height': height,
      'file_size': fileSize,
      'file_hash': fileHash,
      'note': note,
      'mood': mood,
      'tags': tags,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id: map['id'] as String,
      filePath: map['file_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String?,
      tripId: map['trip_id'] as String?,
      dateTaken:
          map['date_taken'] != null
              ? DateTime.tryParse(map['date_taken'] as String)
              : null,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      locationName: map['location_name'] as String?,
      cameraModel: map['camera_model'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      fileSize: map['file_size'] as int?,
      fileHash: map['file_hash'] as String?,
      note: map['note'] as String?,
      mood: map['mood'] as String?,
      tags: map['tags'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Photo && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
