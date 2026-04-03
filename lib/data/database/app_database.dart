import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// SQLite database helper — singleton for the entire app lifecycle.
///
/// Uses a [Completer] to prevent race conditions when multiple callers
/// request the database before initialization finishes.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _database;
  Completer<Database>? _completer;

  Future<Database> get database async {
    if (_database != null) return _database!;

    // If initialization is already in progress, wait for it
    if (_completer != null) return _completer!.future;

    _completer = Completer<Database>();
    try {
      _database = await _initDatabase();
      _completer!.complete(_database!);
    } catch (e) {
      _completer!.completeError(e);
      _completer = null;
      rethrow;
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Trips table
    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        cover_photo_path TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT,
        color TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Photos table
    await db.execute('''
      CREATE TABLE photos (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        thumbnail_path TEXT,
        trip_id TEXT,
        date_taken TEXT,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        location_name TEXT,
        camera_model TEXT,
        width INTEGER,
        height INTEGER,
        file_size INTEGER,
        note TEXT,
        mood TEXT,
        tags TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL
      )
    ''');

    // Journal entries table
    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        trip_id TEXT,
        photo_id TEXT,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        mood TEXT,
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL,
        FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE SET NULL
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_photos_trip_id ON photos(trip_id)');
    await db.execute(
      'CREATE INDEX idx_photos_date_taken ON photos(date_taken)',
    );
    await db.execute(
      'CREATE INDEX idx_photos_location ON photos(latitude, longitude)',
    );
    await db.execute(
      'CREATE INDEX idx_journal_trip_id ON journal_entries(trip_id)',
    );
    await db.execute('CREATE INDEX idx_journal_date ON journal_entries(date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _completer = null;
    }
  }
}
