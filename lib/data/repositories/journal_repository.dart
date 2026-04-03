import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/timeline_day.dart';

/// Repository for JournalEntry CRUD operations.
class JournalRepository {
  final AppDatabase _db;

  JournalRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<Database> get _database => _db.database;

  /// Insert a new journal entry
  Future<void> insert(JournalEntry entry) async {
    final db = await _database;
    await db.insert(
      'journal_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing journal entry
  Future<void> update(JournalEntry entry) async {
    final db = await _database;
    await db.update(
      'journal_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Delete a journal entry
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Get journal entry by ID
  Future<JournalEntry?> getById(String id) async {
    final db = await _database;
    final maps = await db.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return JournalEntry.fromMap(maps.first);
  }

  /// Get all journal entries for a trip
  Future<List<JournalEntry>> getByTripId(String tripId) async {
    final db = await _database;
    final maps = await db.query(
      'journal_entries',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => JournalEntry.fromMap(m)).toList();
  }

  /// Get journal entry for a specific photo
  Future<JournalEntry?> getByPhotoId(String photoId) async {
    final db = await _database;
    final maps = await db.query(
      'journal_entries',
      where: 'photo_id = ?',
      whereArgs: [photoId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return JournalEntry.fromMap(maps.first);
  }

  /// Get all journal entries
  Future<List<JournalEntry>> getAll() async {
    final db = await _database;
    final maps = await db.query('journal_entries', orderBy: 'date DESC');
    return maps.map((m) => JournalEntry.fromMap(m)).toList();
  }
}
