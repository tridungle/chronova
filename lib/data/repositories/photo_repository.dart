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
}
