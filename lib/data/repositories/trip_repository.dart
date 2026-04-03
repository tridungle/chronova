import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/trip.dart';

/// Repository for Trip CRUD operations.
class TripRepository {
  final AppDatabase _db;

  TripRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<Database> get _database => _db.database;

  /// Insert a new trip
  Future<void> insert(Trip trip) async {
    final db = await _database;
    await db.insert(
      'trips',
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing trip
  Future<void> update(Trip trip) async {
    final db = await _database;
    await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  /// Delete a trip by ID
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  /// Get a trip by ID
  Future<Trip?> getById(String id) async {
    final db = await _database;
    final maps = await db.query('trips', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Trip.fromMap(maps.first);
  }

  /// Get all trips ordered by start date descending
  Future<List<Trip>> getAll() async {
    final db = await _database;
    final maps = await db.query('trips', orderBy: 'start_date DESC');
    return maps.map((m) => Trip.fromMap(m)).toList();
  }

  /// Get the photo count for a trip
  Future<int> getPhotoCount(String tripId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photos WHERE trip_id = ?',
      [tripId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
