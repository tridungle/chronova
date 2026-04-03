/// Data model representing a Trip (collection of photos/days).
class Trip {
  final String id;
  final String name;
  final String? description;
  final String? coverPhotoPath;
  final DateTime startDate;
  final DateTime? endDate;
  final String? color; // hex color for polyline
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    required this.name,
    this.description,
    this.coverPhotoPath,
    required this.startDate,
    this.endDate,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  Trip copyWith({
    String? id,
    String? name,
    String? description,
    String? coverPhotoPath,
    DateTime? startDate,
    DateTime? endDate,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_photo_path': coverPhotoPath,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      coverPhotoPath: map['cover_photo_path'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate:
          map['end_date'] != null
              ? DateTime.parse(map['end_date'] as String)
              : null,
      color: map['color'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Trip && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
