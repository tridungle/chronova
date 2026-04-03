import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/photo.dart';

/// Repository for Photo CRUD operations.
class PhotoRepository {
  final AppDatabase _db;

  PhotoRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<Database> get _database => _db.database;

  /// Insert a new photo
  Future<void> insert(Photo photo) async {
    final db = await _database;
    await db.insert(
      'photos',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple photos in a transaction (batch)
  Future<void> insertAll(List<Photo> photos) async {
    final db = await _database;
    final batch = db.batch();
    for (final photo in photos) {
      batch.insert(
        'photos',
        photo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Update an existing photo
  Future<void> update(Photo photo) async {
    final db = await _database;
    await db.update(
      'photos',
      photo.toMap(),
      where: 'id = ?',
      whereArgs: [photo.id],
    );
  }

  /// Delete a photo by ID
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  /// Get a photo by ID
  Future<Photo?> getById(String id) async {
    final db = await _database;
    final maps = await db.query('photos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Photo.fromMap(maps.first);
  }

  /// Get all photos ordered by date taken
  Future<List<Photo>> getAll() async {
    final db = await _database;
    final maps = await db.query(
      'photos',
      orderBy: 'date_taken ASC, sort_order ASC',
    );
    return maps.map((m) => Photo.fromMap(m)).toList();
  }

  /// Get photos for a specific trip
  Future<List<Photo>> getByTripId(String tripId) async {
    final db = await _database;
    final maps = await db.query(
      'photos',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'date_taken ASC, sort_order ASC',
    );
    return maps.map((m) => Photo.fromMap(m)).toList();
  }

  /// Get photos without a trip (unassigned)
  Future<List<Photo>> getUnassigned() async {
    final db = await _database;
    final maps = await db.query(
      'photos',
      where: 'trip_id IS NULL',
      orderBy: 'date_taken ASC',
    );
    return maps.map((m) => Photo.fromMap(m)).toList();
  }

  /// Get photos with GPS coordinates
  Future<List<Photo>> getWithLocation() async {
    final db = await _database;
    final maps = await db.query(
      'photos',
      where: 'latitude IS NOT NULL AND longitude IS NOT NULL',
      orderBy: 'date_taken ASC',
    );
    return maps.map((m) => Photo.fromMap(m)).toList();
  }

  /// Get photos grouped by date (returns distinct dates)
  Future<List<String>> getDistinctDates() async {
    final db = await _database;
    final maps = await db.rawQuery(
      "SELECT DISTINCT substr(date_taken, 1, 10) as date_key "
      "FROM photos WHERE date_taken IS NOT NULL "
      "ORDER BY date_key DESC",
    );
    return maps.map((m) => m['date_key'] as String).toList();
  }

  /// Get photos for a specific date
  Future<List<Photo>> getByDate(String dateKey) async {
    final db = await _database;
    final maps = await db.query(
      'photos',
      where: "substr(date_taken, 1, 10) = ?",
      whereArgs: [dateKey],
      orderBy: 'date_taken ASC',
    );
    return maps.map((m) => Photo.fromMap(m)).toList();
  }

  /// Get total photo count
  Future<int> count() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM photos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Search photos by note or location name
  Future<List<Photo>> search(String query) async {
    final db = await _database;
    final maps = await db.query(
      'photos',
      where: 'note LIKE ? OR location_name LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date_taken DESC',
    );
    return maps.map((m) => Photo.fromMap(m)).toList();
  }

  /// Assign photos to a trip
  Future<void> assignToTrip(List<String> photoIds, String tripId) async {
    final db = await _database;
    final batch = db.batch();
    for (final id in photoIds) {
      batch.update(
        'photos',
        {'trip_id': tripId, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Update sort order for a list of photos (used for drag-to-reorder)
  Future<void> updateSortOrders(Map<String, int> idToOrder) async {
    final db = await _database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final entry in idToOrder.entries) {
      batch.update(
        'photos',
        {'sort_order': entry.value, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Remove photos from a trip
  Future<void> removeFromTrip(List<String> photoIds) async {
    final db = await _database;
    final batch = db.batch();
    for (final id in photoIds) {
      batch.update(
        'photos',
        {'trip_id': null, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Check if a photo with the given file hash already exists in the database.
  /// Used for duplicate detection during import.
  ///
  /// Gracefully returns `false` if the `file_hash` column doesn't exist yet
  /// (e.g. migration was skipped during hot reload). Also attempts to add
  /// the column so subsequent calls succeed.
  Future<bool> existsByHash(String fileHash) async {
    final db = await _database;
    try {
      final result = await db.query(
        'photos',
        columns: ['id'],
        where: 'file_hash = ?',
        whereArgs: [fileHash],
        limit: 1,
      );
      return result.isNotEmpty;
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column: file_hash')) {
        // Column missing — attempt to add it now
        try {
          await db.execute('ALTER TABLE photos ADD COLUMN file_hash TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_photos_file_hash ON photos(file_hash)',
          );
        } catch (_) {
          // Column may already exist from a concurrent call — ignore
        }
        return false;
      }
      rethrow;
    }
  }

  /// Update the file_hash for a single photo (used for backfilling).
  /// Silently skips if the column doesn't exist yet.
  Future<void> updateFileHash(String id, String fileHash) async {
    final db = await _database;
    try {
      await db.update(
        'photos',
        {'file_hash': fileHash, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.toString().contains('no such column: file_hash')) {
        // Column missing — attempt to add it, then retry
        try {
          await db.execute('ALTER TABLE photos ADD COLUMN file_hash TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_photos_file_hash ON photos(file_hash)',
          );
          await db.update(
            'photos',
            {
              'file_hash': fileHash,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } catch (_) {
          // Best-effort — skip if still failing
        }
      } else {
        rethrow;
      }
    }
  }

  /// Update EXIF metadata fields for a single photo.
  /// Used by the re-scan EXIF feature to refresh metadata from files.
  Future<void> updateExifFields(
    String id, {
    DateTime? dateTaken,
    double? latitude,
    double? longitude,
    double? altitude,
    String? cameraModel,
    int? width,
    int? height,
  }) async {
    final db = await _database;
    final fields = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    // Only update fields that have values (don't overwrite existing non-null
    // data with null unless the EXIF truly had nothing).
    if (dateTaken != null) {
      fields['date_taken'] = dateTaken.toIso8601String();
    }
    if (latitude != null) fields['latitude'] = latitude;
    if (longitude != null) fields['longitude'] = longitude;
    if (altitude != null) fields['altitude'] = altitude;
    if (cameraModel != null) fields['camera_model'] = cameraModel;
    if (width != null) fields['width'] = width;
    if (height != null) fields['height'] = height;

    await db.update('photos', fields, where: 'id = ?', whereArgs: [id]);
  }
}
