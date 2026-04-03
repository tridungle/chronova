import 'package:flutter_test/flutter_test.dart';
import 'package:chronova/data/models/trip.dart';

void main() {
  group('Trip', () {
    final now = DateTime(2024, 7, 1, 12, 0, 0);
    final trip = Trip(
      id: 'trip-1',
      name: 'Japan 2024',
      description: 'Cherry blossom season trip',
      coverPhotoPath: '/cover.jpg',
      startDate: DateTime(2024, 3, 25),
      endDate: DateTime(2024, 4, 10),
      color: '#FF5733',
      createdAt: now,
      updatedAt: now,
    );

    group('construction', () {
      test('creates with all fields', () {
        expect(trip.id, 'trip-1');
        expect(trip.name, 'Japan 2024');
        expect(trip.description, 'Cherry blossom season trip');
        expect(trip.coverPhotoPath, '/cover.jpg');
        expect(trip.startDate, DateTime(2024, 3, 25));
        expect(trip.endDate, DateTime(2024, 4, 10));
        expect(trip.color, '#FF5733');
      });

      test('nullable fields default to null', () {
        final t = Trip(
          id: 't',
          name: 'Test',
          startDate: now,
          createdAt: now,
          updatedAt: now,
        );
        expect(t.description, isNull);
        expect(t.coverPhotoPath, isNull);
        expect(t.endDate, isNull);
        expect(t.color, isNull);
      });
    });

    group('copyWith', () {
      test('copies all fields when unchanged', () {
        final copy = trip.copyWith();
        expect(copy.id, trip.id);
        expect(copy.name, trip.name);
        expect(copy.description, trip.description);
        expect(copy.coverPhotoPath, trip.coverPhotoPath);
        expect(copy.startDate, trip.startDate);
        expect(copy.endDate, trip.endDate);
        expect(copy.color, trip.color);
      });

      test('changes specified non-nullable fields', () {
        final copy = trip.copyWith(name: 'Korea 2024');
        expect(copy.name, 'Korea 2024');
        expect(copy.description, trip.description); // unchanged
      });

      test('can null out nullable fields', () {
        final copy = trip.copyWith(
          description: null,
          coverPhotoPath: null,
          endDate: null,
          color: null,
        );
        expect(copy.description, isNull);
        expect(copy.coverPhotoPath, isNull);
        expect(copy.endDate, isNull);
        expect(copy.color, isNull);
      });

      test('preserves nullable fields when not specified', () {
        final copy = trip.copyWith(name: 'Changed name');
        expect(copy.description, 'Cherry blossom season trip');
        expect(copy.endDate, DateTime(2024, 4, 10));
      });
    });

    group('serialization', () {
      test('toMap produces correct map', () {
        final map = trip.toMap();
        expect(map['id'], 'trip-1');
        expect(map['name'], 'Japan 2024');
        expect(map['description'], 'Cherry blossom season trip');
        expect(map['cover_photo_path'], '/cover.jpg');
        expect(map['start_date'], DateTime(2024, 3, 25).toIso8601String());
        expect(map['end_date'], DateTime(2024, 4, 10).toIso8601String());
        expect(map['color'], '#FF5733');
      });

      test('fromMap reconstructs Trip correctly', () {
        final map = trip.toMap();
        final reconstructed = Trip.fromMap(map);
        expect(reconstructed.id, trip.id);
        expect(reconstructed.name, trip.name);
        expect(reconstructed.description, trip.description);
        expect(reconstructed.startDate, trip.startDate);
        expect(reconstructed.endDate, trip.endDate);
        expect(reconstructed.color, trip.color);
      });

      test('fromMap handles null optional fields', () {
        final map = {
          'id': 't1',
          'name': 'Test',
          'start_date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        final t = Trip.fromMap(map);
        expect(t.description, isNull);
        expect(t.coverPhotoPath, isNull);
        expect(t.endDate, isNull);
        expect(t.color, isNull);
      });

      test('fromMap handles invalid dates gracefully', () {
        final map = {
          'id': 't1',
          'name': 'Test',
          'start_date': 'not-a-date',
          'created_at': 'bad',
          'updated_at': 'bad',
        };
        final t = Trip.fromMap(map);
        // Should fall back to DateTime.now()
        expect(t.startDate, isNotNull);
        expect(t.createdAt, isNotNull);
        expect(t.updatedAt, isNotNull);
      });

      test('roundtrip toMap/fromMap preserves data', () {
        final map = trip.toMap();
        final roundtripped = Trip.fromMap(map);
        expect(roundtripped, equals(trip));
      });
    });

    group('equality', () {
      test('trips with same id are equal', () {
        final other = Trip(
          id: 'trip-1',
          name: 'Different Name',
          startDate: DateTime(2020),
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        );
        expect(trip, equals(other));
      });

      test('trips with different id are not equal', () {
        final other = trip.copyWith(id: 'trip-2');
        expect(trip, isNot(equals(other)));
      });
    });
  });
}
