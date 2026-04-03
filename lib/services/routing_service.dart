import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Transportation mode for route calculation.
enum TransportMode {
  car(label: 'Car', icon: Icons.directions_car_rounded, osrmProfile: 'driving'),
  walking(
    label: 'Walking',
    icon: Icons.directions_walk_rounded,
    osrmProfile: 'foot',
  ),
  cycling(
    label: 'Cycling',
    icon: Icons.directions_bike_rounded,
    osrmProfile: 'bike',
  ),
  plane(
    label: 'Plane',
    icon: Icons.flight_rounded,
    osrmProfile: null, // straight-line — no routing needed
  );

  final String label;
  final IconData icon;

  /// OSRM profile name, or null for straight-line mode.
  final String? osrmProfile;

  const TransportMode({
    required this.label,
    required this.icon,
    required this.osrmProfile,
  });
}

/// Service that fetches real road-following routes between GPS waypoints
/// using the OSRM (Open Source Routing Machine) public demo API.
///
/// For "plane" mode, returns straight-line segments directly.
class RoutingService {
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';

  /// Get a detailed route between waypoints for the given transport mode.
  ///
  /// Returns a list of [LatLng] points that follow real roads (or straight
  /// lines for plane mode). The list includes the original waypoints plus
  /// all intermediate road-geometry points.
  ///
  /// [waypoints] must have at least 2 points.
  Future<List<LatLng>> getRoute({
    required List<LatLng> waypoints,
    required TransportMode mode,
  }) async {
    if (waypoints.length < 2) return waypoints;

    // Plane mode: return straight lines (original bird's-eye behavior)
    if (mode == TransportMode.plane) {
      return _straightLineRoute(waypoints);
    }

    // For road-based modes, call OSRM API
    try {
      return await _fetchOsrmRoute(waypoints, mode.osrmProfile!);
    } catch (e) {
      debugPrint('OSRM routing failed, falling back to straight lines: $e');
      // Graceful fallback if the API is unavailable or fails
      return _straightLineRoute(waypoints);
    }
  }

  /// Fetches a route from OSRM for the given profile.
  ///
  /// OSRM accepts up to 100 waypoints per request. For longer trips we
  /// batch into groups and concatenate the results.
  Future<List<LatLng>> _fetchOsrmRoute(
    List<LatLng> waypoints,
    String profile,
  ) async {
    // OSRM has a limit of ~100 waypoints per request.
    // Batch if needed, with overlap to ensure continuity.
    const maxWaypoints = 80;
    if (waypoints.length <= maxWaypoints) {
      return _fetchSingleOsrmRoute(waypoints, profile);
    }

    // Batch into overlapping chunks
    final allPoints = <LatLng>[];
    for (
      int start = 0;
      start < waypoints.length - 1;
      start += maxWaypoints - 1
    ) {
      final end = (start + maxWaypoints).clamp(0, waypoints.length);
      final chunk = waypoints.sublist(start, end);
      final chunkRoute = await _fetchSingleOsrmRoute(chunk, profile);

      if (allPoints.isNotEmpty && chunkRoute.isNotEmpty) {
        // Remove the overlapping first point to avoid duplicates
        allPoints.addAll(chunkRoute.skip(1));
      } else {
        allPoints.addAll(chunkRoute);
      }
    }

    return allPoints;
  }

  /// Calls the OSRM route API for a single batch of waypoints.
  Future<List<LatLng>> _fetchSingleOsrmRoute(
    List<LatLng> waypoints,
    String profile,
  ) async {
    // Build the coordinates string: "lng,lat;lng,lat;..."
    final coords = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    final url = Uri.parse(
      '$_osrmBaseUrl/route/v1/$profile/$coords'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('OSRM API returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final code = json['code'] as String?;
    if (code != 'Ok') {
      throw Exception('OSRM returned code: $code');
    }

    final routes = json['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw Exception('No routes returned from OSRM');
    }

    // Parse the GeoJSON geometry from the first (best) route
    final geometry = routes[0]['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;

    return coordinates.map<LatLng>((coord) {
      // GeoJSON is [longitude, latitude]
      return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
    }).toList();
  }

  /// Returns a straight-line route with intermediate points for smoother
  /// animation. Adds interpolated points between distant waypoints.
  List<LatLng> _straightLineRoute(List<LatLng> waypoints) {
    final result = <LatLng>[];
    for (int i = 0; i < waypoints.length; i++) {
      result.add(waypoints[i]);
      if (i < waypoints.length - 1) {
        // Add intermediate points for long segments to make the animation
        // smoother (great-circle-like behavior for long distances).
        final from = waypoints[i];
        final to = waypoints[i + 1];
        final dist = _haversineDistance(from, to);
        // Add an interpolated point every ~50km for smoothness
        final numIntermediate = (dist / 50000).floor().clamp(0, 20);
        for (int j = 1; j <= numIntermediate; j++) {
          final t = j / (numIntermediate + 1);
          result.add(
            LatLng(
              from.latitude + (to.latitude - from.latitude) * t,
              from.longitude + (to.longitude - from.longitude) * t,
            ),
          );
        }
      }
    }
    return result;
  }

  /// Simple Haversine distance in meters between two points.
  static double _haversineDistance(LatLng a, LatLng b) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, a, b);
  }
}
