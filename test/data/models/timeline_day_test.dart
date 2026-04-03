import 'package:flutter_test/flutter_test.dart';
import 'package:chronova/data/models/photo.dart';
import 'package:chronova/data/models/timeline_day.dart';

void main() {
  final now = DateTime(2024, 6, 15);

  Photo _makePhoto({
    required String id,
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return Photo(
      id: id,
      filePath: '/photos/$id.jpg',
      dateTaken: now,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TimelineDay', () {
    group('primaryPhoto', () {
      test('returns first photo with location', () {
        final photos = [
          _makePhoto(id: 'p1'),
          _makePhoto(
            id: 'p2',
            latitude: 35.0,
            longitude: 139.0,
            locationName: 'Tokyo',
          ),
          _makePhoto(
            id: 'p3',
            latitude: 34.0,
            longitude: 135.0,
            locationName: 'Osaka',
          ),
        ];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.primaryPhoto?.id, 'p2');
      });

      test('returns first photo when none have location', () {
        final photos = [_makePhoto(id: 'p1'), _makePhoto(id: 'p2')];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.primaryPhoto?.id, 'p1');
      });

      test('returns null for empty photo list', () {
        final day = TimelineDay(date: now, photos: []);
        expect(day.primaryPhoto, isNull);
      });
    });

    group('photosWithLocation', () {
      test('counts photos with GPS coordinates', () {
        final photos = [
          _makePhoto(id: 'p1'),
          _makePhoto(id: 'p2', latitude: 35.0, longitude: 139.0),
          _makePhoto(id: 'p3', latitude: 34.0, longitude: 135.0),
        ];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.photosWithLocation, 2);
      });

      test('returns 0 when no photos have location', () {
        final photos = [_makePhoto(id: 'p1'), _makePhoto(id: 'p2')];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.photosWithLocation, 0);
      });
    });

    group('locations', () {
      test('returns unique location names', () {
        final photos = [
          _makePhoto(
            id: 'p1',
            latitude: 35.0,
            longitude: 139.0,
            locationName: 'Tokyo',
          ),
          _makePhoto(
            id: 'p2',
            latitude: 35.0,
            longitude: 139.0,
            locationName: 'Tokyo',
          ),
          _makePhoto(
            id: 'p3',
            latitude: 34.0,
            longitude: 135.0,
            locationName: 'Osaka',
          ),
        ];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.locations, containsAll(['Tokyo', 'Osaka']));
        expect(day.locations.length, 2);
      });

      test('returns empty list when no photos have location names', () {
        final photos = [_makePhoto(id: 'p1')];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.locations, isEmpty);
      });
    });
  });

  group('JournalEntry', () {
    final entry = JournalEntry(
      id: 'j1',
      tripId: 'trip-1',
      photoId: 'photo-1',
      date: now,
      content: 'A wonderful day exploring the city.',
      mood: '😊',
      tags: 'travel,food,culture',
      createdAt: now,
      updatedAt: now,
    );

    group('construction', () {
      test('creates with all fields', () {
        expect(entry.id, 'j1');
        expect(entry.tripId, 'trip-1');
        expect(entry.photoId, 'photo-1');
        expect(entry.content, 'A wonderful day exploring the city.');
        expect(entry.mood, '😊');
        expect(entry.tags, 'travel,food,culture');
      });

      test('nullable fields default to null', () {
        final e = JournalEntry(
          id: 'j',
          date: now,
          content: 'test',
          createdAt: now,
          updatedAt: now,
        );
        expect(e.tripId, isNull);
        expect(e.photoId, isNull);
        expect(e.mood, isNull);
        expect(e.tags, isNull);
      });
    });

    group('tagList', () {
      test('splits tags correctly', () {
        expect(entry.tagList, ['travel', 'food', 'culture']);
      });

      test('returns empty for null tags', () {
        final e = entry.copyWith(tags: null);
        expect(e.tagList, isEmpty);
      });

      test('filters empty segments', () {
        final e = entry.copyWith(tags: 'a,,b, ,c');
        expect(e.tagList, ['a', 'b', 'c']);
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final copy = entry.copyWith();
        expect(copy.id, entry.id);
        expect(copy.tripId, entry.tripId);
        expect(copy.content, entry.content);
        expect(copy.mood, entry.mood);
      });

      test('can null out nullable fields', () {
        final copy = entry.copyWith(
          tripId: null,
          photoId: null,
          mood: null,
          tags: null,
        );
        expect(copy.tripId, isNull);
        expect(copy.photoId, isNull);
        expect(copy.mood, isNull);
        expect(copy.tags, isNull);
      });

      test('preserves nullable fields when not specified', () {
        final copy = entry.copyWith(content: 'New content');
        expect(copy.content, 'New content');
        expect(copy.tripId, 'trip-1'); // preserved
        expect(copy.mood, '😊'); // preserved
      });
    });

    group('serialization', () {
      test('toMap produces correct map', () {
        final map = entry.toMap();
        expect(map['id'], 'j1');
        expect(map['trip_id'], 'trip-1');
        expect(map['photo_id'], 'photo-1');
        expect(map['content'], 'A wonderful day exploring the city.');
        expect(map['mood'], '😊');
        expect(map['tags'], 'travel,food,culture');
      });

      test('fromMap reconstructs JournalEntry correctly', () {
        final map = entry.toMap();
        final reconstructed = JournalEntry.fromMap(map);
        expect(reconstructed.id, entry.id);
        expect(reconstructed.tripId, entry.tripId);
        expect(reconstructed.content, entry.content);
        expect(reconstructed.mood, entry.mood);
      });

      test('fromMap handles null optional fields', () {
        final map = {
          'id': 'j1',
          'date': now.toIso8601String(),
          'content': 'test',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final e = JournalEntry.fromMap(map);
        expect(e.tripId, isNull);
        expect(e.photoId, isNull);
        expect(e.mood, isNull);
        expect(e.tags, isNull);
      });

      test('fromMap handles invalid dates', () {
        final map = {
          'id': 'j1',
          'date': 'bad-date',
          'content': 'test',
          'created_at': 'bad',
          'updated_at': 'bad',
        };
        final e = JournalEntry.fromMap(map);
        expect(e.date, isNotNull);
        expect(e.createdAt, isNotNull);
      });

      test('roundtrip toMap/fromMap preserves data', () {
        final map = entry.toMap();
        final roundtripped = JournalEntry.fromMap(map);
        expect(roundtripped.id, entry.id);
        expect(roundtripped.tripId, entry.tripId);
        expect(roundtripped.content, entry.content);
        expect(roundtripped.mood, entry.mood);
        expect(roundtripped.tags, entry.tags);
        expect(roundtripped.date, entry.date);
      });
    });
  });
}
