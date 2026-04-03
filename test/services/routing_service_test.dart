import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:chronova/services/routing_service.dart';

void main() {
  // ─── TransportMode tests ─────────────────────────────────────

  group('TransportMode', () {
    test('has exactly 4 modes', () {
      expect(TransportMode.values.length, 4);
    });

    test('car has correct properties', () {
      expect(TransportMode.car.label, 'Car');
      expect(TransportMode.car.icon, Icons.directions_car_rounded);
      expect(TransportMode.car.osrmProfile, 'driving');
    });

    test('walking has correct properties', () {
      expect(TransportMode.walking.label, 'Walking');
      expect(TransportMode.walking.icon, Icons.directions_walk_rounded);
      expect(TransportMode.walking.osrmProfile, 'foot');
    });

    test('cycling has correct properties', () {
      expect(TransportMode.cycling.label, 'Cycling');
      expect(TransportMode.cycling.icon, Icons.directions_bike_rounded);
      expect(TransportMode.cycling.osrmProfile, 'bike');
    });

    test('plane has null osrmProfile (straight-line)', () {
      expect(TransportMode.plane.label, 'Plane');
      expect(TransportMode.plane.icon, Icons.flight_rounded);
      expect(TransportMode.plane.osrmProfile, isNull);
    });

    test('all modes have non-empty labels', () {
      for (final mode in TransportMode.values) {
        expect(mode.label.isNotEmpty, isTrue);
      }
    });
  });

  // ─── RoutingService tests ────────────────────────────────────

  group('RoutingService', () {
    late RoutingService service;

    setUp(() {
      service = RoutingService();
    });

    test('returns input unchanged when fewer than 2 waypoints', () async {
      final single = [const LatLng(48.8566, 2.3522)]; // Paris
      final result = await service.getRoute(
        waypoints: single,
        mode: TransportMode.car,
      );
      expect(result, single);
    });

    test('returns empty list for empty input', () async {
      final result = await service.getRoute(
        waypoints: [],
        mode: TransportMode.car,
      );
      expect(result, isEmpty);
    });

    // ─── Plane mode (synchronous straight-line, no API) ─────

    group('plane mode (straight-line)', () {
      test('returns at least the original waypoints', () async {
        final waypoints = [
          const LatLng(48.8566, 2.3522), // Paris
          const LatLng(51.5074, -0.1278), // London
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.plane,
        );

        // Should include start and end at minimum
        expect(result.first.latitude, waypoints.first.latitude);
        expect(result.first.longitude, waypoints.first.longitude);
        expect(result.last.latitude, waypoints.last.latitude);
        expect(result.last.longitude, waypoints.last.longitude);
        // Route should have >= 2 points
        expect(result.length, greaterThanOrEqualTo(2));
      });

      test('adds interpolated points for long distances', () async {
        // Paris to Tokyo: ~9700 km — should add many intermediate points
        final waypoints = [
          const LatLng(48.8566, 2.3522), // Paris
          const LatLng(35.6762, 139.6503), // Tokyo
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.plane,
        );

        // Distance is ~9700km, so at ~50km per intermediate point
        // should produce many intermediate points
        expect(result.length, greaterThan(2));
      });

      test('does not add intermediate points for short distances', () async {
        // Two nearby points (< 50km apart)
        final waypoints = [
          const LatLng(48.8566, 2.3522), // Paris
          const LatLng(48.8606, 2.3376), // ~1km away
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.plane,
        );

        // Should be exactly 2 (no interpolation for <50km)
        expect(result.length, 2);
      });

      test('preserves all original waypoints in output', () async {
        final waypoints = [
          const LatLng(48.8566, 2.3522), // Paris
          const LatLng(45.4642, 9.1900), // Milan
          const LatLng(41.9028, 12.4964), // Rome
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.plane,
        );

        // All original waypoints should be present (at start of each segment)
        expect(result.contains(waypoints[0]), isTrue);
        expect(result.contains(waypoints[2]), isTrue);
        // Middle waypoint should also be present
        expect(result.contains(waypoints[1]), isTrue);
      });

      test('handles 3+ waypoints correctly', () async {
        final waypoints = [
          const LatLng(0, 0),
          const LatLng(0, 0.001), // very close
          const LatLng(0, 0.002), // very close
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.plane,
        );

        // Short distances — no interpolation, should be exactly 3
        expect(result.length, 3);
        expect(result[0], waypoints[0]);
        expect(result[1], waypoints[1]);
        expect(result[2], waypoints[2]);
      });
    });

    // ─── Road-based modes (require network — these test fallback) ──

    group('road-based modes with fallback', () {
      // Note: These tests exercise the real OSRM API when available,
      // and gracefully fall back to straight lines when offline.
      // They are designed to pass in both cases.

      test('car mode returns a route with at least the endpoints', () async {
        final waypoints = [
          const LatLng(48.8566, 2.3522), // Paris
          const LatLng(48.8606, 2.3376), // ~1km away
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.car,
        );

        expect(result.length, greaterThanOrEqualTo(2));
        // Start and end should be near the original waypoints
        // (OSRM may snap to nearest road, so we check proximity)
        final startDist = const Distance().as(
          LengthUnit.Meter,
          result.first,
          waypoints.first,
        );
        final endDist = const Distance().as(
          LengthUnit.Meter,
          result.last,
          waypoints.last,
        );
        // Should be within 500m of original waypoints
        expect(startDist, lessThan(500));
        expect(endDist, lessThan(500));
      });

      test('walking mode returns a valid route', () async {
        final waypoints = [
          const LatLng(48.8566, 2.3522),
          const LatLng(48.8606, 2.3376),
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.walking,
        );

        expect(result.length, greaterThanOrEqualTo(2));
      });

      test('cycling mode returns a valid route', () async {
        final waypoints = [
          const LatLng(48.8566, 2.3522),
          const LatLng(48.8606, 2.3376),
        ];
        final result = await service.getRoute(
          waypoints: waypoints,
          mode: TransportMode.cycling,
        );

        expect(result.length, greaterThanOrEqualTo(2));
      });
    });
  });
}
