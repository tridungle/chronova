import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chronova/data/models/photo.dart';
import 'package:chronova/services/photo_import_service.dart';

void main() {
  group('Photo', () {
    final now = DateTime(2024, 6, 15, 10, 30, 0);
    final photo = Photo(
      id: 'photo-1',
      filePath: '/path/to/photo.jpg',
      thumbnailPath: '/path/to/thumb.jpg',
      tripId: 'trip-1',
      dateTaken: now,
      latitude: 35.6762,
      longitude: 139.6503,
      altitude: 40.5,
      locationName: 'Tokyo, Japan',
      cameraModel: 'iPhone 15 Pro',
      width: 4032,
      height: 3024,
      fileSize: 5242880,
      fileHash: 'abc123sha256hash',
      note: 'Beautiful cherry blossoms',
      mood: '🌸',
      tags: 'travel,japan,spring',
      sortOrder: 3,
      createdAt: now,
      updatedAt: now,
    );

    group('construction', () {
      test('creates with all fields', () {
        expect(photo.id, 'photo-1');
        expect(photo.filePath, '/path/to/photo.jpg');
        expect(photo.thumbnailPath, '/path/to/thumb.jpg');
        expect(photo.tripId, 'trip-1');
        expect(photo.dateTaken, now);
        expect(photo.latitude, 35.6762);
        expect(photo.longitude, 139.6503);
        expect(photo.altitude, 40.5);
        expect(photo.locationName, 'Tokyo, Japan');
        expect(photo.cameraModel, 'iPhone 15 Pro');
        expect(photo.width, 4032);
        expect(photo.height, 3024);
        expect(photo.fileSize, 5242880);
        expect(photo.note, 'Beautiful cherry blossoms');
        expect(photo.mood, '🌸');
        expect(photo.tags, 'travel,japan,spring');
        expect(photo.sortOrder, 3);
      });

      test('defaults sortOrder to 0', () {
        final p = Photo(
          id: 'p',
          filePath: '/f',
          createdAt: now,
          updatedAt: now,
        );
        expect(p.sortOrder, 0);
      });

      test('nullable fields default to null', () {
        final p = Photo(
          id: 'p',
          filePath: '/f',
          createdAt: now,
          updatedAt: now,
        );
        expect(p.thumbnailPath, isNull);
        expect(p.tripId, isNull);
        expect(p.dateTaken, isNull);
        expect(p.latitude, isNull);
        expect(p.longitude, isNull);
        expect(p.altitude, isNull);
        expect(p.locationName, isNull);
        expect(p.cameraModel, isNull);
        expect(p.width, isNull);
        expect(p.height, isNull);
        expect(p.fileSize, isNull);
        expect(p.fileHash, isNull);
        expect(p.note, isNull);
        expect(p.mood, isNull);
        expect(p.tags, isNull);
      });
    });

    group('computed properties', () {
      test('hasLocation returns true when both lat/lng are set', () {
        expect(photo.hasLocation, isTrue);
      });

      test('hasLocation returns false when lat is null', () {
        final p = photo.copyWith(latitude: null);
        expect(p.hasLocation, isFalse);
      });

      test('hasLocation returns false when lng is null', () {
        final p = photo.copyWith(longitude: null);
        expect(p.hasLocation, isFalse);
      });

      test('hasDate returns true when dateTaken is set', () {
        expect(photo.hasDate, isTrue);
      });

      test('hasDate returns false when dateTaken is null', () {
        final p = photo.copyWith(dateTaken: null);
        expect(p.hasDate, isFalse);
      });

      test('tagList splits tags correctly', () {
        expect(photo.tagList, ['travel', 'japan', 'spring']);
      });

      test('tagList returns empty for null tags', () {
        final p = photo.copyWith(tags: null);
        expect(p.tagList, isEmpty);
      });

      test('tagList handles empty string tags', () {
        final p = photo.copyWith(tags: '');
        expect(p.tagList, isEmpty);
      });

      test('tagList filters whitespace-only tags', () {
        final p = photo.copyWith(tags: 'a,,  ,b');
        expect(p.tagList, ['a', 'b']);
      });
    });

    group('copyWith', () {
      test('copies all fields when unchanged', () {
        final copy = photo.copyWith();
        expect(copy.id, photo.id);
        expect(copy.filePath, photo.filePath);
        expect(copy.tripId, photo.tripId);
        expect(copy.latitude, photo.latitude);
        expect(copy.note, photo.note);
        expect(copy.sortOrder, photo.sortOrder);
      });

      test('changes specified fields', () {
        final copy = photo.copyWith(
          id: 'new-id',
          note: 'Updated note',
          sortOrder: 5,
        );
        expect(copy.id, 'new-id');
        expect(copy.note, 'Updated note');
        expect(copy.sortOrder, 5);
        // unchanged fields
        expect(copy.filePath, photo.filePath);
        expect(copy.tripId, photo.tripId);
      });

      test('can null out nullable fields with sentinel pattern', () {
        final copy = photo.copyWith(
          tripId: null,
          locationName: null,
          note: null,
          mood: null,
          tags: null,
          latitude: null,
          longitude: null,
          altitude: null,
          dateTaken: null,
          thumbnailPath: null,
          cameraModel: null,
          fileHash: null,
        );
        expect(copy.tripId, isNull);
        expect(copy.locationName, isNull);
        expect(copy.note, isNull);
        expect(copy.mood, isNull);
        expect(copy.tags, isNull);
        expect(copy.latitude, isNull);
        expect(copy.longitude, isNull);
        expect(copy.altitude, isNull);
        expect(copy.dateTaken, isNull);
        expect(copy.thumbnailPath, isNull);
        expect(copy.cameraModel, isNull);
        expect(copy.fileHash, isNull);
      });

      test('sentinel pattern preserves non-null values when not specified', () {
        // When a nullable field is NOT passed at all, it should keep its value
        final copy = photo.copyWith(note: 'Changed only note');
        expect(copy.note, 'Changed only note');
        expect(copy.tripId, 'trip-1'); // preserved
        expect(copy.locationName, 'Tokyo, Japan'); // preserved
      });
    });

    group('serialization', () {
      test('toMap produces correct map', () {
        final map = photo.toMap();
        expect(map['id'], 'photo-1');
        expect(map['file_path'], '/path/to/photo.jpg');
        expect(map['thumbnail_path'], '/path/to/thumb.jpg');
        expect(map['trip_id'], 'trip-1');
        expect(map['date_taken'], now.toIso8601String());
        expect(map['latitude'], 35.6762);
        expect(map['longitude'], 139.6503);
        expect(map['altitude'], 40.5);
        expect(map['location_name'], 'Tokyo, Japan');
        expect(map['camera_model'], 'iPhone 15 Pro');
        expect(map['width'], 4032);
        expect(map['height'], 3024);
        expect(map['file_size'], 5242880);
        expect(map['file_hash'], 'abc123sha256hash');
        expect(map['note'], 'Beautiful cherry blossoms');
        expect(map['mood'], '🌸');
        expect(map['tags'], 'travel,japan,spring');
        expect(map['sort_order'], 3);
        expect(map['created_at'], now.toIso8601String());
        expect(map['updated_at'], now.toIso8601String());
      });

      test('fromMap reconstructs Photo correctly', () {
        final map = photo.toMap();
        final reconstructed = Photo.fromMap(map);
        expect(reconstructed.id, photo.id);
        expect(reconstructed.filePath, photo.filePath);
        expect(reconstructed.tripId, photo.tripId);
        expect(reconstructed.latitude, photo.latitude);
        expect(reconstructed.longitude, photo.longitude);
        expect(reconstructed.note, photo.note);
        expect(reconstructed.sortOrder, photo.sortOrder);
        expect(reconstructed.dateTaken, photo.dateTaken);
      });

      test('fromMap handles null optional fields', () {
        final map = {
          'id': 'p1',
          'file_path': '/f',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final p = Photo.fromMap(map);
        expect(p.tripId, isNull);
        expect(p.dateTaken, isNull);
        expect(p.latitude, isNull);
        expect(p.locationName, isNull);
        expect(p.sortOrder, 0); // default
      });

      test('fromMap handles num types for doubles (SQLite compat)', () {
        final map = {
          'id': 'p1',
          'file_path': '/f',
          'latitude': 35, // int, not double
          'longitude': 139, // int, not double
          'altitude': 40, // int, not double
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final p = Photo.fromMap(map);
        expect(p.latitude, 35.0);
        expect(p.longitude, 139.0);
        expect(p.altitude, 40.0);
      });

      test('fromMap handles invalid date_taken gracefully', () {
        final map = {
          'id': 'p1',
          'file_path': '/f',
          'date_taken': 'not-a-date',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final p = Photo.fromMap(map);
        expect(p.dateTaken, isNull);
      });

      test('fromMap defaults createdAt/updatedAt on bad strings', () {
        final map = {
          'id': 'p1',
          'file_path': '/f',
          'created_at': 'bad',
          'updated_at': 'bad',
        };
        final p = Photo.fromMap(map);
        // Should fall back to DateTime.now() — just check it's not null
        expect(p.createdAt, isNotNull);
        expect(p.updatedAt, isNotNull);
      });

      test('roundtrip toMap/fromMap preserves data', () {
        final map = photo.toMap();
        final roundtripped = Photo.fromMap(map);
        expect(roundtripped, equals(photo));
      });
    });

    group('equality', () {
      test('photos with same id are equal', () {
        final other = Photo(
          id: 'photo-1',
          filePath: '/different/path.jpg',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        );
        expect(photo, equals(other));
      });

      test('photos with different id are not equal', () {
        final other = photo.copyWith(id: 'photo-2');
        expect(photo, isNot(equals(other)));
      });

      test('hashCode matches for equal photos', () {
        final other = Photo(
          id: 'photo-1',
          filePath: '/other',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        );
        expect(photo.hashCode, equals(other.hashCode));
      });
    });
  });

  group('ImportResult', () {
    test('duplicateCount is included in constructor', () {
      const result = ImportResult(
        totalFiles: 10,
        successCount: 7,
        failedCount: 1,
        duplicateCount: 2,
        withExifDate: 5,
        withGps: 3,
        photos: [],
      );
      expect(result.totalFiles, 10);
      expect(result.successCount, 7);
      expect(result.failedCount, 1);
      expect(result.duplicateCount, 2);
      expect(result.withExifDate, 5);
      expect(result.withGps, 3);
    });

    test('duplicateCount defaults to 0 in typical zero result', () {
      const result = ImportResult(
        totalFiles: 0,
        successCount: 0,
        failedCount: 0,
        duplicateCount: 0,
        withExifDate: 0,
        withGps: 0,
        photos: [],
      );
      expect(result.duplicateCount, 0);
    });
  });

  group('PhotoImportService.computeFileHash', () {
    test('computes SHA-256 hash for a file', () async {
      // Create a temporary file with known content
      final tempDir = Directory.systemTemp.createTempSync('hash_test');
      final file = File('${tempDir.path}/test.txt');
      file.writeAsStringSync('hello world');

      final hash = await PhotoImportService.computeFileHash(file);

      // SHA-256 of "hello world"
      expect(
        hash,
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
      );

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    test('same content produces same hash', () async {
      final tempDir = Directory.systemTemp.createTempSync('hash_test2');
      final file1 = File('${tempDir.path}/a.txt');
      final file2 = File('${tempDir.path}/b.txt');
      file1.writeAsStringSync('identical content');
      file2.writeAsStringSync('identical content');

      final hash1 = await PhotoImportService.computeFileHash(file1);
      final hash2 = await PhotoImportService.computeFileHash(file2);
      expect(hash1, hash2);

      tempDir.deleteSync(recursive: true);
    });

    test('different content produces different hash', () async {
      final tempDir = Directory.systemTemp.createTempSync('hash_test3');
      final file1 = File('${tempDir.path}/a.txt');
      final file2 = File('${tempDir.path}/b.txt');
      file1.writeAsStringSync('content A');
      file2.writeAsStringSync('content B');

      final hash1 = await PhotoImportService.computeFileHash(file1);
      final hash2 = await PhotoImportService.computeFileHash(file2);
      expect(hash1, isNot(hash2));

      tempDir.deleteSync(recursive: true);
    });

    test('hash is a 64-character hex string', () async {
      final tempDir = Directory.systemTemp.createTempSync('hash_test4');
      final file = File('${tempDir.path}/test.bin');
      file.writeAsBytesSync([0, 1, 2, 3, 255]);

      final hash = await PhotoImportService.computeFileHash(file);
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);

      tempDir.deleteSync(recursive: true);
    });
  });
}
