import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/widgets.dart';

/// Parsed EXIF data from a photo file.
class ExifData {
  final DateTime? dateTaken;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final String? cameraModel;
  final int? width;
  final int? height;

  const ExifData({
    this.dateTaken,
    this.latitude,
    this.longitude,
    this.altitude,
    this.cameraModel,
    this.width,
    this.height,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasDate => dateTaken != null;
}

/// Service to extract EXIF metadata from photo files.
class ExifService {
  /// Extract EXIF data from a file path.
  Future<ExifData> extractFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const ExifData();
    }

    final bytes = await file.readAsBytes();
    return _parseExifData(bytes);
  }

  /// Parse EXIF from bytes
  static Future<ExifData> _parseExifData(Uint8List bytes) async {
    try {
      final data = await readExifFromBytes(bytes);
      if (data.isEmpty) return const ExifData();

      return ExifData(
        dateTaken: _parseDateTime(data),
        latitude: _parseGpsLatitude(data),
        longitude: _parseGpsLongitude(data),
        altitude: _parseAltitude(data),
        cameraModel: _parseCameraModel(data),
        width: _parseImageDimension(data, 'EXIF ExifImageWidth'),
        height: _parseImageDimension(data, 'EXIF ExifImageLength'),
      );
    } catch (e) {
      debugPrint('EXIF parse error: $e');
      return const ExifData();
    }
  }

  /// Parse DateTimeOriginal or DateTimeDigitized
  static DateTime? _parseDateTime(Map<String, IfdTag> data) {
    final dateStr =
        data['EXIF DateTimeOriginal']?.printable ??
        data['EXIF DateTimeDigitized']?.printable ??
        data['Image DateTime']?.printable;

    return parseExifDateString(dateStr);
  }

  /// Parse an EXIF date string like "2024:01:15 14:30:00" into a [DateTime].
  ///
  /// EXIF stores dates with colons in the date portion (yyyy:MM:dd HH:mm:ss).
  /// This converts it to ISO 8601 format before parsing.
  /// Returns null if the string is null, empty, or unparseable.
  @visibleForTesting
  static DateTime? parseExifDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    try {
      // EXIF date format: "2024:01:15 14:30:00"
      // Convert to ISO 8601: "2024-01-15 14:30:00"
      final cleaned = dateStr.replaceFirstMapped(
        RegExp(r'^(\d{4}):(\d{2}):(\d{2})'),
        (m) => '${m[1]}-${m[2]}-${m[3]}',
      );
      return DateTime.tryParse(cleaned);
    } catch (_) {
      return null;
    }
  }

  /// Parse GPS latitude
  static double? _parseGpsLatitude(Map<String, IfdTag> data) {
    final lat = data['GPS GPSLatitude'];
    final latRef = data['GPS GPSLatitudeRef'];
    if (lat == null) return null;

    final value = _gpsToDouble(lat);
    if (value == null) return null;

    return (latRef?.printable == 'S') ? -value : value;
  }

  /// Parse GPS longitude
  static double? _parseGpsLongitude(Map<String, IfdTag> data) {
    final lon = data['GPS GPSLongitude'];
    final lonRef = data['GPS GPSLongitudeRef'];
    if (lon == null) return null;

    final value = _gpsToDouble(lon);
    if (value == null) return null;

    return (lonRef?.printable == 'W') ? -value : value;
  }

  /// Parse GPS altitude
  static double? _parseAltitude(Map<String, IfdTag> data) {
    final alt = data['GPS GPSAltitude'];
    if (alt == null) return null;

    try {
      final ratio = alt.values as IfdRatios;
      final r = ratio.ratios.first;
      if (r.denominator == 0) return null;
      return r.numerator / r.denominator;
    } catch (_) {
      return null;
    }
  }

  /// Parse camera model
  static String? _parseCameraModel(Map<String, IfdTag> data) {
    final make = data['Image Make']?.printable;
    final model = data['Image Model']?.printable;

    if (make == null && model == null) return null;
    if (make != null && model != null) {
      // Avoid duplication like "Apple Apple iPhone 15"
      if (model.contains(make)) return model;
      return '$make $model';
    }
    return model ?? make;
  }

  /// Parse image dimension (width/height)
  static int? _parseImageDimension(Map<String, IfdTag> data, String key) {
    final tag = data[key];
    if (tag == null) return null;
    try {
      return int.tryParse(tag.printable);
    } catch (_) {
      return null;
    }
  }

  /// Convert GPS IFD tag to a double value
  /// GPS coordinates are stored as [degrees, minutes, seconds]
  static double? _gpsToDouble(IfdTag tag) {
    try {
      final ratios = tag.values as IfdRatios;
      final values = ratios.ratios;
      if (values.length < 3) return null;

      // Guard against division by zero in any component
      if (values[0].denominator == 0 ||
          values[1].denominator == 0 ||
          values[2].denominator == 0) {
        return null;
      }

      final degrees = values[0].numerator / values[0].denominator;
      final minutes = values[1].numerator / values[1].denominator;
      final seconds = values[2].numerator / values[2].denominator;

      return degrees + (minutes / 60.0) + (seconds / 3600.0);
    } catch (_) {
      return null;
    }
  }
}
