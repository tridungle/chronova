import 'package:geocoding/geocoding.dart';
import 'package:flutter/widgets.dart';

/// Service for reverse geocoding GPS coordinates to location names.
class LocationService {
  /// Reverse geocode coordinates to a human-readable location name.
  /// Returns "City, Country" or "Country" if city is unavailable.
  Future<String?> getLocationName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = <String>[];

      if (place.locality?.isNotEmpty == true) {
        parts.add(place.locality!);
      } else if (place.subAdministrativeArea?.isNotEmpty == true) {
        parts.add(place.subAdministrativeArea!);
      }

      if (place.country?.isNotEmpty == true) {
        parts.add(place.country!);
      }

      return parts.isNotEmpty ? parts.join(', ') : null;
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      return null;
    }
  }

  /// Get a short location name (just city or region)
  Future<String?> getShortLocationName(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      return place.locality ??
          place.subAdministrativeArea ??
          place.administrativeArea ??
          place.country;
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      return null;
    }
  }
}
