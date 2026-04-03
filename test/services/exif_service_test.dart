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

    group('parseExifDateString', () {
      test('parses standard EXIF date format "YYYY:MM:DD HH:MM:SS"', () {
        final result = ExifService.parseExifDateString('2024:01:15 14:30:00');
        expect(result, isNotNull);
        expect(result, DateTime(2024, 1, 15, 14, 30, 0));
      });

      test('parses date with different values', () {
        final result = ExifService.parseExifDateString('2023:12:25 08:00:45');
        expect(result, DateTime(2023, 12, 25, 8, 0, 45));
      });

      test('parses date with midnight time', () {
        final result = ExifService.parseExifDateString('2020:06:01 00:00:00');
        expect(result, DateTime(2020, 6, 1));
      });

      test('returns null for null input', () {
        expect(ExifService.parseExifDateString(null), isNull);
      });

      test('returns null for empty string', () {
        expect(ExifService.parseExifDateString(''), isNull);
      });

      test('returns null for unparseable string', () {
        expect(ExifService.parseExifDateString('not-a-date'), isNull);
      });

      test('handles date-only without time component', () {
        // "2024:01:15" becomes "2024-01-15" which DateTime.tryParse can handle
        final result = ExifService.parseExifDateString('2024:01:15');
        expect(result, DateTime(2024, 1, 15));
      });

      test('regression: replaceFirstMapped produces correct backreferences', () {
        // This test guards against the bug where replaceFirst with r'$1-$2-$3'
        // inserted literal "$1-$2-$3" instead of capture group values.
        final result = ExifService.parseExifDateString('2024:01:15 14:30:00');
        expect(
          result,
          isNotNull,
          reason:
              'Must not return null — the old replaceFirst(r"\$1-\$2-\$3") '
              'bug caused this to always be null',
        );
        expect(result!.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
        expect(result.hour, 14);
        expect(result.minute, 30);
        expect(result.second, 0);
      });
    });
  });
}
