import 'package:flutter_test/flutter_test.dart';
import 'package:chronova/data/models/photo.dart';
import 'package:chronova/data/models/timeline_day.dart';

void main() {
  final now = DateTime(2024, 6, 15);

  Photo makePhoto({
    required String id,
    double? latitude,
    double? longitude,
    String? locationName,
    String? mood,
    String? note,
  }) {
    return Photo(
      id: id,
      filePath: '/photos/$id.jpg',
      dateTaken: now,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      mood: mood,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TimelineDay', () {
    group('primaryPhoto', () {
      test('returns first photo with location', () {
        final photos = [
          makePhoto(id: 'p1'),
          makePhoto(
            id: 'p2',
            latitude: 35.0,
            longitude: 139.0,
            locationName: 'Tokyo',
          ),
          makePhoto(
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
        final photos = [makePhoto(id: 'p1'), makePhoto(id: 'p2')];
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
          makePhoto(id: 'p1'),
          makePhoto(id: 'p2', latitude: 35.0, longitude: 139.0),
          makePhoto(id: 'p3', latitude: 34.0, longitude: 135.0),
        ];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.photosWithLocation, 2);
      });

      test('returns 0 when no photos have location', () {
        final photos = [makePhoto(id: 'p1'), makePhoto(id: 'p2')];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.photosWithLocation, 0);
      });
    });

    group('locations', () {
      test('returns unique location names', () {
        final photos = [
          makePhoto(
            id: 'p1',
            latitude: 35.0,
            longitude: 139.0,
            locationName: 'Tokyo',
          ),
          makePhoto(
            id: 'p2',
            latitude: 35.0,
            longitude: 139.0,
            locationName: 'Tokyo',
          ),
          makePhoto(
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
        final photos = [makePhoto(id: 'p1')];
        final day = TimelineDay(date: now, photos: photos);
        expect(day.locations, isEmpty);
      });
    });

    group('hasMultipleLocations', () {
      test('returns true when locationGroups has 2+ entries', () {
        final day = TimelineDay(
          date: now,
          photos: [makePhoto(id: 'p1')],
          locationGroups: [
            LocationGroup(
              label: 'Tokyo',
              photos: [makePhoto(id: 'p1', locationName: 'Tokyo')],
            ),
            LocationGroup(
              label: 'Osaka',
              photos: [makePhoto(id: 'p2', locationName: 'Osaka')],
            ),
          ],
        );
        expect(day.hasMultipleLocations, isTrue);
      });

      test('returns false when locationGroups has 0 or 1 entry', () {
        final day = TimelineDay(date: now, photos: [makePhoto(id: 'p1')]);
        expect(day.hasMultipleLocations, isFalse);

        final day2 = TimelineDay(
          date: now,
          photos: [makePhoto(id: 'p1')],
          locationGroups: [
            LocationGroup(
              label: 'Tokyo',
              photos: [makePhoto(id: 'p1', locationName: 'Tokyo')],
            ),
          ],
        );
        expect(day2.hasMultipleLocations, isFalse);
      });
    });

    group('groupByLocation', () {
      test('groups photos by locationName', () {
        final photos = [
          makePhoto(id: 'p1', locationName: 'Tokyo'),
          makePhoto(id: 'p2', locationName: 'Osaka'),
          makePhoto(id: 'p3', locationName: 'Tokyo'),
        ];
        final groups = TimelineDay.groupByLocation(photos);
        expect(groups.length, 2);
        expect(groups[0].label, 'Tokyo');
        expect(groups[0].photos.length, 2);
        expect(groups[1].label, 'Osaka');
        expect(groups[1].photos.length, 1);
      });

      test('puts unknown-location photos in a separate group at the end', () {
        final photos = [
          makePhoto(id: 'p1', locationName: 'Tokyo'),
          makePhoto(id: 'p2'), // no location
          makePhoto(id: 'p3', locationName: 'Tokyo'),
          makePhoto(id: 'p4'), // no location
        ];
        final groups = TimelineDay.groupByLocation(photos);
        expect(groups.length, 2);
        expect(groups[0].label, 'Tokyo');
        expect(groups[0].isUnknown, isFalse);
        expect(groups[1].label, LocationGroup.unknownLabel);
        expect(groups[1].isUnknown, isTrue);
        expect(groups[1].photos.length, 2);
      });

      test('returns single group when all photos have same location', () {
        final photos = [
          makePhoto(id: 'p1', locationName: 'Paris'),
          makePhoto(id: 'p2', locationName: 'Paris'),
        ];
        final groups = TimelineDay.groupByLocation(photos);
        expect(groups.length, 1);
        expect(groups[0].label, 'Paris');
      });

      test('returns single unknown group when no photos have locations', () {
        final photos = [makePhoto(id: 'p1'), makePhoto(id: 'p2')];
        final groups = TimelineDay.groupByLocation(photos);
        expect(groups.length, 1);
        expect(groups[0].isUnknown, isTrue);
      });

      test('returns empty list for empty input', () {
        final groups = TimelineDay.groupByLocation([]);
        expect(groups, isEmpty);
      });

      test('handles many distinct locations', () {
        final photos = [
          makePhoto(id: 'p1', locationName: 'A'),
          makePhoto(id: 'p2', locationName: 'B'),
          makePhoto(id: 'p3', locationName: 'C'),
          makePhoto(id: 'p4'), // unknown
        ];
        final groups = TimelineDay.groupByLocation(photos);
        expect(groups.length, 4);
        // Named locations first, unknown last
        expect(groups[0].label, 'A');
        expect(groups[1].label, 'B');
        expect(groups[2].label, 'C');
        expect(groups[3].isUnknown, isTrue);
      });
    });
  });

  group('LocationGroup', () {
    test('primaryPhoto returns first photo with location', () {
      final photos = [
        makePhoto(id: 'p1'),
        makePhoto(id: 'p2', latitude: 35.0, longitude: 139.0),
      ];
      final group = LocationGroup(label: 'Test', photos: photos);
      expect(group.primaryPhoto?.id, 'p2');
    });

    test('primaryPhoto returns first photo when none have location', () {
      final photos = [makePhoto(id: 'p1'), makePhoto(id: 'p2')];
      final group = LocationGroup(label: 'Test', photos: photos);
      expect(group.primaryPhoto?.id, 'p1');
    });

    test('primaryPhoto returns null for empty list', () {
      final group = LocationGroup(label: 'Test', photos: []);
      expect(group.primaryPhoto, isNull);
    });

    test('unknownLabel is "Unknown Location"', () {
      expect(LocationGroup.unknownLabel, 'Unknown Location');
    });

    group('mood', () {
      test('returns first non-null mood from photos', () {
        final photos = [
          makePhoto(id: 'p1'),
          makePhoto(id: 'p2', mood: '😊'),
          makePhoto(id: 'p3', mood: '🎉'),
        ];
        final group = LocationGroup(label: 'Test', photos: photos);
        expect(group.mood, '😊');
      });

      test('returns null when no photos have mood', () {
        final photos = [makePhoto(id: 'p1'), makePhoto(id: 'p2')];
        final group = LocationGroup(label: 'Test', photos: photos);
        expect(group.mood, isNull);
      });

      test('returns null for empty photo list', () {
        final group = LocationGroup(label: 'Test', photos: []);
        expect(group.mood, isNull);
      });
    });

    group('note', () {
      test('returns first non-null non-empty note from photos', () {
        final photos = [
          makePhoto(id: 'p1'),
          makePhoto(id: 'p2', note: 'Great view!'),
          makePhoto(id: 'p3', note: 'Also nice'),
        ];
        final group = LocationGroup(label: 'Test', photos: photos);
        expect(group.note, 'Great view!');
      });

      test('skips empty string notes', () {
        final photos = [
          makePhoto(id: 'p1', note: ''),
          makePhoto(id: 'p2', note: 'Real note'),
        ];
        final group = LocationGroup(label: 'Test', photos: photos);
        expect(group.note, 'Real note');
      });

      test('returns null when no photos have notes', () {
        final photos = [makePhoto(id: 'p1'), makePhoto(id: 'p2')];
        final group = LocationGroup(label: 'Test', photos: photos);
        expect(group.note, isNull);
      });

      test('returns null for empty photo list', () {
        final group = LocationGroup(label: 'Test', photos: []);
        expect(group.note, isNull);
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
