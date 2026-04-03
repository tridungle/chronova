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

  /// Get list of tags
  List<String> get tagList =>
      tags?.split(',').where((t) => t.trim().isNotEmpty).toList() ?? [];

  Photo copyWith({
    String? id,
    String? filePath,
    String? thumbnailPath,
    String? tripId,
    DateTime? dateTaken,
    double? latitude,
    double? longitude,
    double? altitude,
    String? locationName,
    String? cameraModel,
    int? width,
    int? height,
    int? fileSize,
    String? note,
    String? mood,
    String? tags,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Photo(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      tripId: tripId ?? this.tripId,
      dateTaken: dateTaken ?? this.dateTaken,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      locationName: locationName ?? this.locationName,
      cameraModel: cameraModel ?? this.cameraModel,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      note: note ?? this.note,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
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
              ? DateTime.parse(map['date_taken'] as String)
              : null,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      altitude: map['altitude'] as double?,
      locationName: map['location_name'] as String?,
      cameraModel: map['camera_model'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      fileSize: map['file_size'] as int?,
      note: map['note'] as String?,
      mood: map['mood'] as String?,
      tags: map['tags'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Photo && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
