import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/timeline/timeline_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/trips/trips_screen.dart';
import '../../features/trips/trip_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/photo_import/photo_import_screen.dart';
import '../../features/video_export/video_export_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/home/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/timeline',
  routes: [
    // Main shell with bottom navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/timeline',
          pageBuilder:
              (context, state) =>
                  const NoTransitionPage(child: TimelineScreen()),
        ),
        GoRoute(
          path: '/map',
          pageBuilder:
              (context, state) => const NoTransitionPage(child: MapScreen()),
        ),
        GoRoute(
          path: '/trips',
          pageBuilder:
              (context, state) => const NoTransitionPage(child: TripsScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder:
              (context, state) =>
                  const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),

    // Full-screen routes (outside shell)
    GoRoute(
      path: '/trip/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder:
          (context, state) =>
              TripDetailScreen(tripId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/import',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        // Accept optional tripId via query parameter or extra
        final tripId =
            state.uri.queryParameters['tripId'] ?? state.extra as String?;
        return PhotoImportScreen(tripId: tripId);
      },
    ),
    GoRoute(
      path: '/export',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const VideoExportScreen(),
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SearchScreen(),
    ),
  ],
);
