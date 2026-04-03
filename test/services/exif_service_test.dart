import 'package:flutter_test/flutter_test.dart';
import 'package:chronova/services/exif_service.dart';

void main() {
  group('ExifData', () {
    group('hasLocation', () {
      test('returns true when both lat/lng are set', () {
        const data = ExifData(latitude: 35.0, longitude: 139.0);
        expect(data.hasLocation, isTrue);
      });

      test('returns false when latitude is null', () {
        const data = ExifData(longitude: 139.0);
        expect(data.hasLocation, isFalse);
      });

      test('returns false when longitude is null', () {
        const data = ExifData(latitude: 35.0);
        expect(data.hasLocation, isFalse);
      });

      test('returns false when both are null', () {
        const data = ExifData();
        expect(data.hasLocation, isFalse);
      });
    });

    group('hasDate', () {
      test('returns true when dateTaken is set', () {
        final data = ExifData(dateTaken: DateTime(2024, 1, 1));
        expect(data.hasDate, isTrue);
      });

      test('returns false when dateTaken is null', () {
        const data = ExifData();
        expect(data.hasDate, isFalse);
      });
    });

    group('construction', () {
      test('all fields default to null', () {
        const data = ExifData();
        expect(data.dateTaken, isNull);
        expect(data.latitude, isNull);
        expect(data.longitude, isNull);
        expect(data.altitude, isNull);
        expect(data.cameraModel, isNull);
        expect(data.width, isNull);
        expect(data.height, isNull);
      });

      test('creates with all fields', () {
        final data = ExifData(
          dateTaken: DateTime(2024, 6, 15),
          latitude: 35.6762,
          longitude: 139.6503,
          altitude: 40.5,
          cameraModel: 'iPhone 15 Pro',
          width: 4032,
          height: 3024,
        );
        expect(data.dateTaken, DateTime(2024, 6, 15));
        expect(data.latitude, 35.6762);
        expect(data.longitude, 139.6503);
        expect(data.altitude, 40.5);
        expect(data.cameraModel, 'iPhone 15 Pro');
        expect(data.width, 4032);
        expect(data.height, 3024);
      });
    });
  });

  group('ExifService', () {
    test(
      'extractFromFile returns empty ExifData for non-existent file',
      () async {
        final service = ExifService();
        final data = await service.extractFromFile('/nonexistent/path.jpg');
        expect(data.hasLocation, isFalse);
        expect(data.hasDate, isFalse);
        expect(data.cameraModel, isNull);
      },
    );
  });
}
