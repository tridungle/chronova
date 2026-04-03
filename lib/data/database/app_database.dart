import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/photo_path_resolver.dart';

/// SQLite database helper — singleton for the entire app lifecycle.
///
/// Uses a [Completer] to prevent race conditions when multiple callers
/// request the database before initialization finishes.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _database;
  Completer<Database>? _completer;
  bool _schemaVerified = false;

  Future<Database> get database async {
    if (_database != null) {
      // Ensure schema is correct even on cached instances (hot reload safety)
      if (!_schemaVerified) {
        await _ensureSchema(_database!);
        _schemaVerified = true;
      }
      return _database!;
    }

    // If initialization is already in progress, wait for it
    if (_completer != null) return _completer!.future;

    _completer = Completer<Database>();
    try {
      _database = await _initDatabase();
      _schemaVerified = true; // _onOpen already verified
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
      onOpen: _onOpen,
    );
  }

  /// Ensures the DB schema has all expected columns and migrates stale
  /// absolute file paths to relative paths.
  ///
  /// This runs on the first `database` access per app session, even if
  /// the cached `_database` instance pre-dates a code change that added
  /// new columns. Handles the hot-reload case where `_onOpen`/`_onUpgrade`
  /// were never called because `openDatabase()` was never re-invoked.
  Future<void> _ensureSchema(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(photos)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (!columnNames.contains('file_hash')) {
        await db.execute('ALTER TABLE photos ADD COLUMN file_hash TEXT');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_photos_file_hash ON photos(file_hash)',
        );
        debugPrint('AppDatabase: added file_hash column via _ensureSchema');
      }

      // Migrate absolute file_path values to relative paths.
      // This fixes the iOS sandbox UUID change issue where absolute paths
      // become stale after Xcode rebuild / reinstall.
      await _migrateToRelativePaths(db);
    } catch (e) {
      debugPrint('AppDatabase: _ensureSchema failed: $e');
    }
  }

  /// Convert any absolute `file_path` values in the photos table to relative
  /// paths (e.g., `photos/<uuid>.jpg`). This is idempotent — already-relative
  /// paths are left untouched.
  Future<void> _migrateToRelativePaths(Database db) async {
    try {
      // Find all photos with absolute paths (start with '/')
      final rows = await db.query(
        'photos',
        columns: ['id', 'file_path'],
        where: "file_path LIKE '/%'",
      );

      if (rows.isEmpty) return;

      final resolver = PhotoPathResolver.instance;
      // Ensure resolver is initialised (should already be from main.dart)
      await resolver.init();

      final batch = db.batch();
      int migrated = 0;

      for (final row in rows) {
        final id = row['id'] as String;
        final absolutePath = row['file_path'] as String;
        final relativePath = resolver.toRelative(absolutePath);

        // Only update if the path actually changed
        if (relativePath != absolutePath) {
          batch.update(
            'photos',
            {'file_path': relativePath},
            where: 'id = ?',
            whereArgs: [id],
          );
          migrated++;
        }
      }

      if (migrated > 0) {
        await batch.commit(noResult: true);
        debugPrint('AppDatabase: migrated $migrated photo paths to relative');
      }
    } catch (e) {
      debugPrint('AppDatabase: path migration failed: $e');
    }
  }

  /// Safety net: ensure all expected columns exist even if _onUpgrade was
  /// skipped (e.g. hot restart with a cached singleton holding version 1).
  Future<void> _onOpen(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(photos)');
      final hasFileHash = columns.any((c) => c['name'] == 'file_hash');
      if (!hasFileHash) {
        await db.execute('ALTER TABLE photos ADD COLUMN file_hash TEXT');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_photos_file_hash ON photos(file_hash)',
        );
        debugPrint('AppDatabase: backfilled file_hash column via onOpen');
      }
    } catch (e) {
      debugPrint('AppDatabase: onOpen safety check failed: $e');
    }
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
        file_hash TEXT,
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
    await db.execute('CREATE INDEX idx_photos_file_hash ON photos(file_hash)');
    await db.execute(
      'CREATE INDEX idx_journal_trip_id ON journal_entries(trip_id)',
    );
    await db.execute('CREATE INDEX idx_journal_date ON journal_entries(date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add file_hash column for duplicate detection (SHA-256 of file content).
      // Check if column already exists (defensive — handles partial migrations).
      final columns = await db.rawQuery('PRAGMA table_info(photos)');
      final hasFileHash = columns.any((c) => c['name'] == 'file_hash');
      if (!hasFileHash) {
        await db.execute('ALTER TABLE photos ADD COLUMN file_hash TEXT');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_photos_file_hash ON photos(file_hash)',
        );
      }
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _completer = null;
      _schemaVerified = false;
    }
  }
}
