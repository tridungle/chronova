import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_retry_widget.dart';
import '../../data/models/models.dart';
import '../../services/routing_service.dart';

/// Transparent 1x1 pixel PNG used as placeholder when map tiles fail to load.
final _kTransparentTile = MemoryImage(
  Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x62,
    0x00,
    0x00,
    0x00,
    0x02,
    0x00,
    0x01,
    0xE5,
    0x27,
    0xDE,
    0xFC,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]),
);

/// Cinematic video export screen — TravelBoast/Polarsteps style.
///
/// Features:
///   - Real road-following routes via OSRM API
///   - Transport mode selector (car, walking, cycling, plane)
///   - Progressive path reveal — polyline draws behind the moving icon
///   - Transport icon that moves along the route with heading rotation
///   - Animated GIF export via pure-Dart `image` package
class VideoExportScreen extends ConsumerStatefulWidget {
  const VideoExportScreen({super.key});

  @override
  ConsumerState<VideoExportScreen> createState() => _VideoExportScreenState();
}

class _VideoExportScreenState extends ConsumerState<VideoExportScreen>
    with TickerProviderStateMixin {
  // RepaintBoundary key for frame capture
  final GlobalKey _mapBoundaryKey = GlobalKey();

  // Animation state
  late AnimationController _flyController;
  bool _isPreviewPlaying = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String? _exportedFilePath;

  // Settings
  double _animationSpeed = AppConstants.defaultAnimationSpeedSec;
  int _selectedColorIndex = 0;
  final double _polylineThickness = 4.0;
  bool _showPhotoPopups = true;
  int _framesPerSegment = 10;
  double _zoomLevel = 12.0;
  bool _useEasing = true;

  // Transport / routing state
  TransportMode _transportMode = TransportMode.car;
  List<LatLng> _routedPath = []; // full routed path (road geometry)
  List<double> _cumulativeDistances = []; // for uniform-speed animation
  double _totalRouteDistance = 0.0;
  List<int> _waypointPathIndices = []; // maps each waypoint to _routedPath idx
  bool _isFetchingRoute = false;
  String? _routeError;

  // Map state
  final MapController _mapController = MapController();
  int _currentSegment = 0;
  Photo? _currentPopupPhoto;

  // Camera follow mode — when true, camera auto-moves with transport icon.
  // User can disable by interacting with the map, re-enable via a button.
  bool _cameraFollowMode = true;

  // Data
  List<Photo> _geoPhotos = [];
  List<LatLng> _waypoints = []; // original photo waypoints

  // Progress along the routed path (index into _routedPath, fractional)
  double _progressAlongPath = 0.0;

  // The current interpolated position of the transport icon — used for both
  // the marker AND the polyline tip so they are always in perfect sync.
  LatLng? _currentIconPosition;

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _flyController.addListener(_onAnimationTick);
    _flyController.addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _flyController.removeListener(_onAnimationTick);
    _flyController.removeStatusListener(_onAnimationStatus);
    _flyController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ─── Route fetching ─────────────────────────────────────────────

  /// Fetch route from OSRM (or straight lines for plane mode).
  Future<void> _fetchRoute() async {
    if (_waypoints.length < 2) return;

    setState(() {
      _isFetchingRoute = true;
      _routeError = null;
    });

    try {
      final routingService = ref.read(routingServiceProvider);
      final path = await routingService.getRoute(
        waypoints: _waypoints,
        mode: _transportMode,
      );

      if (!mounted) return;

      // Build cumulative distances for uniform-speed interpolation
      final distances = <double>[0.0];
      double total = 0.0;
      for (int i = 1; i < path.length; i++) {
        total += const Distance().as(LengthUnit.Meter, path[i - 1], path[i]);
        distances.add(total);
      }

      // Map each original waypoint to its nearest index on the routed path
      final waypointIndices = <int>[];
      for (final wp in _waypoints) {
        int bestIdx = 0;
        double bestDist = double.infinity;
        for (int i = 0; i < path.length; i++) {
          final d = const Distance().as(LengthUnit.Meter, wp, path[i]);
          if (d < bestDist) {
            bestDist = d;
            bestIdx = i;
          }
        }
        waypointIndices.add(bestIdx);
      }

      setState(() {
        _routedPath = path;
        _cumulativeDistances = distances;
        _totalRouteDistance = total;
        _waypointPathIndices = waypointIndices;
        _isFetchingRoute = false;
      });
    } catch (e) {
      debugPrint('Route fetch error: $e');
      if (!mounted) return;
      setState(() {
        _isFetchingRoute = false;
        _routeError = e.toString();
        // Fallback: use waypoints directly
        _routedPath = List.of(_waypoints);
        _cumulativeDistances = [0.0];
        double total = 0.0;
        for (int i = 1; i < _routedPath.length; i++) {
          total += const Distance().as(
            LengthUnit.Meter,
            _routedPath[i - 1],
            _routedPath[i],
          );
          _cumulativeDistances.add(total);
        }
        _totalRouteDistance = total;
        _waypointPathIndices = List.generate(
          _waypoints.length,
          (i) => i.clamp(0, _routedPath.length - 1),
        );
      });
    }
  }

  // ─── Uniform-speed interpolation helpers ────────────────────────

  /// Given a distance along the route, return the position via binary search.
  LatLng _positionAtDistance(double distance) {
    if (_routedPath.isEmpty) return const LatLng(0, 0);
    if (_routedPath.length == 1) return _routedPath.first;
    if (distance <= 0) return _routedPath.first;
    if (distance >= _totalRouteDistance) return _routedPath.last;

    // Binary search for the segment containing this distance
    int lo = 0, hi = _cumulativeDistances.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (_cumulativeDistances[mid] <= distance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final segStart = _cumulativeDistances[lo];
    final segEnd = _cumulativeDistances[hi];
    final segLen = segEnd - segStart;
    final t = segLen > 0 ? (distance - segStart) / segLen : 0.0;

    final from = _routedPath[lo];
    final to = _routedPath[hi];
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// Returns the path index (fractional) at a given distance.
  double _pathIndexAtDistance(double distance) {
    if (_routedPath.length < 2) return 0;
    if (distance <= 0) return 0;
    if (distance >= _totalRouteDistance) {
      return (_routedPath.length - 1).toDouble();
    }

    int lo = 0, hi = _cumulativeDistances.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (_cumulativeDistances[mid] <= distance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final segStart = _cumulativeDistances[lo];
    final segEnd = _cumulativeDistances[hi];
    final segLen = segEnd - segStart;
    final t = segLen > 0 ? (distance - segStart) / segLen : 0.0;
    return lo + t;
  }

  /// The revealed portion of the path (up to the current animation progress).
  ///
  /// Uses [_currentIconPosition] as the tip so the polyline end and the
  /// transport icon marker are always at the exact same coordinates.
  List<LatLng> get _revealedPath {
    if (_routedPath.isEmpty || _progressAlongPath <= 0) return [];
    final idx = _progressAlongPath.floor();

    // Full points up to idx
    final points = _routedPath.sublist(
      0,
      (idx + 1).clamp(0, _routedPath.length),
    );

    // Append the exact icon position as the polyline tip for perfect sync
    if (_currentIconPosition != null) {
      points.add(_currentIconPosition!);
    }

    return points;
  }

  /// Bearing (heading) at the current position for icon rotation.
  double _bearingAtProgress() {
    if (_routedPath.length < 2) return 0;
    final idx = _progressAlongPath.floor().clamp(0, _routedPath.length - 2);
    final from = _routedPath[idx];
    final to = _routedPath[(idx + 1).clamp(0, _routedPath.length - 1)];

    // Calculate bearing in radians
    final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return math.atan2(y, x);
  }

  // ─── Camera helpers ──────────────────────────────────────────────

  /// Fit the camera to show a broader view around the current position.
  ///
  /// Instead of centering directly on the transport icon, this shows a
  /// padded bounding box that includes the current position plus nearby
  /// route points, giving users context of the journey ahead and behind.
  void _fitCameraToProgress(LatLng currentPosition) {
    final contextPoints = <LatLng>[currentPosition];

    // Include surrounding waypoints for geographic context
    for (int i = 0; i < _waypointPathIndices.length; i++) {
      final wpIdx = _waypointPathIndices[i];
      final currentIdx = _progressAlongPath.floor();
      if (wpIdx >= currentIdx - 1 && wpIdx <= currentIdx + 1) {
        contextPoints.add(_waypoints[i]);
      }
    }

    // Add a lookahead point on the routed path so the user sees where
    // the transport icon is heading (5% of total path ahead)
    final lookAheadIdx = (_progressAlongPath.floor() +
            (_routedPath.length * 0.05).round())
        .clamp(0, _routedPath.length - 1);
    contextPoints.add(_routedPath[lookAheadIdx]);

    if (contextPoints.length >= 2) {
      try {
        final bounds = LatLngBounds.fromPoints(contextPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(60),
            maxZoom: 15,
          ),
        );
      } catch (_) {
        // Fallback if bounds computation fails
        _mapController.move(currentPosition, _zoomLevel);
      }
    } else {
      _mapController.move(currentPosition, _zoomLevel);
    }
  }

  // ─── Animation callbacks ────────────────────────────────────────

  void _onAnimationTick() {
    if (_routedPath.length < 2 || _totalRouteDistance <= 0) return;

    // Map animation value (0..1) to distance, applying easing if desired
    double t = _flyController.value;
    if (_useEasing) {
      t = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
    }

    final distance = t * _totalRouteDistance;
    // Compute position ONCE — used for polyline tip AND transport icon
    final position = _positionAtDistance(distance);
    final pathIdx = _pathIndexAtDistance(distance);

    // Fix #3 & #4: Only move camera if follow mode is active.
    // Uses fitCamera to show broader context instead of locking to the icon.
    if (_cameraFollowMode) {
      _fitCameraToProgress(position);
    }

    // Determine which waypoint we've reached (for photo popups)
    int currentWaypointIdx = 0;
    for (int i = 0; i < _waypointPathIndices.length; i++) {
      if (pathIdx >= _waypointPathIndices[i]) {
        currentWaypointIdx = i;
      }
    }

    if (!mounted) return;
    setState(() {
      _progressAlongPath = pathIdx;
      _currentIconPosition = position;

      if (currentWaypointIdx != _currentSegment) {
        _currentSegment = currentWaypointIdx;
        if (_showPhotoPopups && currentWaypointIdx < _geoPhotos.length) {
          _currentPopupPhoto = _geoPhotos[currentWaypointIdx];
        }
      }
    });
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (!mounted) return;
      setState(() {
        _isPreviewPlaying = false;
        _currentPopupPhoto = null;
        _cameraFollowMode = true;
        // Keep the full path revealed after animation completes
        _progressAlongPath = (_routedPath.length - 1).toDouble();
        _currentIconPosition = null;
      });
    }
  }

  void _startPreview() {
    if (_routedPath.length < 2) return;

    // Duration: animationSpeed seconds per original waypoint segment
    final totalDuration = (_animationSpeed * (_waypoints.length - 1)).toInt();
    _flyController.duration = Duration(seconds: totalDuration.clamp(2, 300));
    _flyController.reset();

    setState(() {
      _isPreviewPlaying = true;
      _currentSegment = 0;
      _currentPopupPhoto = null;
      _progressAlongPath = 0;
      _currentIconPosition = null;
      _cameraFollowMode = true; // re-enable follow at preview start
    });

    _mapController.move(_routedPath.first, _zoomLevel);
    _flyController.forward();
  }

  void _stopPreview() {
    _flyController.stop();
    setState(() {
      _isPreviewPlaying = false;
      _currentPopupPhoto = null;
    });
  }

  // ─── Frame capture helpers ───────────────────────────────────

  /// Capture the current map widget as a raw RGBA image.
  Future<img.Image?> _captureFrame() async {
    try {
      final boundary =
          _mapBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final uiImage = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      return img.Image.fromBytes(
        width: uiImage.width,
        height: uiImage.height,
        bytes: byteData.buffer,
        numChannels: 4,
      );
    } catch (e) {
      debugPrint('Frame capture error: $e');
      return null;
    }
  }

  // ─── Export logic ────────────────────────────────────────────

  /// Export the fly-along animation as an animated GIF.
  Future<void> _exportVideo() async {
    if (_routedPath.length < 2) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportedFilePath = null;
    });

    try {
      final totalSegments = _waypoints.length - 1;
      final totalFrames = totalSegments * _framesPerSegment;
      final durationCs = ((_animationSpeed / _framesPerSegment) * 100).round();
      final gifEncoder = img.GifEncoder(delay: durationCs);

      for (int i = 0; i <= totalFrames; i++) {
        double t = i / totalFrames; // 0 -> 1
        if (_useEasing) {
          t = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
        }

        final distance = t * _totalRouteDistance;
        final position = _positionAtDistance(distance);
        final pathIdx = _pathIndexAtDistance(distance);

        // Move the map
        _mapController.move(position, _zoomLevel);

        // Update progress for path reveal and transport icon
        int currentWaypointIdx = 0;
        for (int w = 0; w < _waypointPathIndices.length; w++) {
          if (pathIdx >= _waypointPathIndices[w]) {
            currentWaypointIdx = w;
          }
        }

        if (_showPhotoPopups &&
            currentWaypointIdx < _geoPhotos.length &&
            currentWaypointIdx != _currentSegment) {
          if (!mounted) return;
          setState(() {
            _currentSegment = currentWaypointIdx;
            _currentPopupPhoto = _geoPhotos[currentWaypointIdx];
            _progressAlongPath = pathIdx;
            _currentIconPosition = position;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _progressAlongPath = pathIdx;
            _currentIconPosition = position;
          });
        }

        // Wait for the map to render the new position
        await Future.delayed(const Duration(milliseconds: 80));

        // Capture frame
        final frame = await _captureFrame();
        if (frame != null) {
          gifEncoder.addFrame(frame, duration: durationCs);
        }

        if (!mounted) return;
        setState(() => _exportProgress = (i + 1) / (totalFrames + 1));
      }

      // Finalize and write animated GIF
      final dir = await getTemporaryDirectory();
      final outputPath = p.join(
        dir.path,
        'chronova_journey_${DateTime.now().millisecondsSinceEpoch}.gif',
      );

      setState(() => _exportProgress = 0.95);

      final gifBytes = gifEncoder.finish();
      if (gifBytes == null) throw Exception('GIF encoding returned no data');
      await File(outputPath).writeAsBytes(gifBytes);

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportProgress = 1.0;
        _exportedFilePath = outputPath;
        _currentPopupPhoto = null;
      });

      if (mounted) {
        context.showSnackBar('Journey exported as animated GIF!');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportProgress = 0.0;
      });
      if (mounted) {
        context.showSnackBar('Export failed: $e', isError: true);
      }
    }
  }

  Future<void> _shareVideo() async {
    if (_exportedFilePath != null) {
      await Share.shareXFiles([
        XFile(_exportedFilePath!),
      ], text: 'My travel journey, created with Chronova');
    }
  }

  // ─── Waypoint reordering ────────────────────────────────────────

  /// Preference key for persisted waypoint order (list of photo IDs).
  static const _waypointOrderKey = 'video_export_waypoint_order';

  /// Save the current waypoint order to shared preferences.
  Future<void> _saveWaypointOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _geoPhotos.map((p) => p.id).toList();
    await prefs.setStringList(_waypointOrderKey, ids);
  }

  /// Apply any previously saved waypoint order to the given photos.
  /// Returns the reordered list, or the original if no saved order exists
  /// or the set of photo IDs has changed.
  Future<List<Photo>> _applySavedOrder(List<Photo> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_waypointOrderKey);
    if (savedIds == null || savedIds.isEmpty) return photos;

    // Build a lookup by ID
    final photoMap = {for (final p in photos) p.id: p};
    final currentIds = photoMap.keys.toSet();
    final savedIdSet = savedIds.toSet();

    // Only apply if the saved set matches the current set of photos
    if (!currentIds.containsAll(savedIdSet) ||
        !savedIdSet.containsAll(currentIds)) {
      // Photo set has changed — discard saved order
      await prefs.remove(_waypointOrderKey);
      return photos;
    }

    // Reorder according to saved IDs
    return savedIds.map((id) => photoMap[id]!).toList();
  }

  /// Shows a bottom sheet with a drag-to-reorder list of waypoints.
  /// Users can rearrange photo waypoints before exporting.
  void _showReorderSheet() {
    // Work on a mutable copy so we can cancel without side effects
    final reorderedPhotos = List<Photo>.from(_geoPhotos);

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            'Reorder Waypoints',
                            style: AppTextStyles.subtitle1.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        'Drag to reorder the stops in your journey',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: scrollController,
                        itemCount: reorderedPhotos.length,
                        onReorder: (oldIdx, newIdx) {
                          setSheetState(() {
                            if (newIdx > oldIdx) newIdx--;
                            final item = reorderedPhotos.removeAt(oldIdx);
                            reorderedPhotos.insert(newIdx, item);
                          });
                        },
                        itemBuilder: (ctx, i) {
                          final photo = reorderedPhotos[i];
                          return ListTile(
                            key: ValueKey(photo.resolvedFilePath),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Image.file(
                                  File(photo.resolvedFilePath),
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.photo_outlined,
                                          size: 20,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            title: Text(
                              photo.locationName ?? 'Stop ${i + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body2,
                            ),
                            subtitle:
                                photo.dateTaken != null
                                    ? Text(
                                      photo.dateTaken!.formatted,
                                      style: AppTextStyles.caption,
                                    )
                                    : null,
                            trailing: ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle_rounded),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((applied) {
      if (applied == true) {
        setState(() {
          _geoPhotos = reorderedPhotos;
          _waypoints =
              reorderedPhotos
                  .map((p) => LatLng(p.latitude!, p.longitude!))
                  .toList();
        });
        // Persist the new order and re-fetch the route
        _saveWaypointOrder();
        _fetchRoute();
      }
    });
  }

  // ─── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final geoPhotos = ref.watch(geoPhotosProvider);
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;
    final pathColor = AppTheme.polylineColors[_selectedColorIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Video'),
        actions: [
          if (_exportedFilePath != null)
            IconButton(
              onPressed: _shareVideo,
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share',
            ),
        ],
      ),
      body: geoPhotos.when(
        data: (photos) {
          // Update data only when not animating/exporting
          if (!_isPreviewPlaying && !_isExporting) {
            final newPhotos = photos.where((p) => p.hasLocation).toList();
            final newWaypoints =
                newPhotos
                    .map((p) => LatLng(p.latitude!, p.longitude!))
                    .toList();

            // Re-fetch route if waypoints changed
            if (!_listEquals(newWaypoints, _waypoints)) {
              // Apply saved waypoint order (async — fires route fetch after)
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final orderedPhotos = await _applySavedOrder(newPhotos);
                if (!mounted) return;
                setState(() {
                  _geoPhotos = orderedPhotos;
                  _waypoints =
                      orderedPhotos
                          .map((p) => LatLng(p.latitude!, p.longitude!))
                          .toList();
                });
                if (_waypoints.length >= 2) {
                  _fetchRoute();
                }
              });
            }
          }

          if (_geoPhotos.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Map preview
              Expanded(
                flex: 3,
                child: _buildMapPreview(isDark, pathColor, colorScheme),
              ),
              // Settings panel
              Expanded(flex: 2, child: _buildSettingsPanel(colorScheme)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => ErrorRetryWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(geoPhotosProvider),
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_creation_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No GPS photos available',
            style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Import photos with GPS data first\nto create a travel video.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              GoRouter.of(context).push('/import');
            },
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Import Photos'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview(
    bool isDark,
    Color pathColor,
    ColorScheme colorScheme,
  ) {
    final bounds = LatLngBounds.fromPoints(
      _waypoints.isNotEmpty ? _waypoints : [const LatLng(0, 0)],
    );

    return RepaintBoundary(
      key: _mapBoundaryKey,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: bounds.center,
                initialZoom: 5,
                // Fix #4: Allow all gestures (pinch-zoom, pan, etc.)
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                // Detect user-initiated gestures to disable camera follow
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _isPreviewPlaying && _cameraFollowMode) {
                    setState(() => _cameraFollowMode = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      isDark
                          ? AppConstants.cartoDarkTileUrl
                          : AppConstants.cartoLightTileUrl,
                  userAgentPackageName: 'com.chronova.app',
                  errorImage: _kTransparentTile,
                  evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                ),
                // Ghost path: show full route as faint line when not animating
                if (_routedPath.length >= 2 &&
                    !_isPreviewPlaying &&
                    !_isExporting)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routedPath,
                        strokeWidth: _polylineThickness,
                        color: pathColor.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                // Progressive revealed path (drawn behind moving icon)
                if (_revealedPath.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _revealedPath,
                        strokeWidth: _polylineThickness,
                        color: pathColor,
                      ),
                    ],
                  ),
                // Show full path when not animating but route is loaded
                if (_routedPath.length >= 2 &&
                    !_isPreviewPlaying &&
                    !_isExporting &&
                    _progressAlongPath >= (_routedPath.length - 1).toDouble())
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routedPath,
                        strokeWidth: _polylineThickness,
                        color: pathColor,
                      ),
                    ],
                  ),
                // Waypoint markers
                MarkerLayer(
                  markers:
                      _geoPhotos.map((photo) {
                        return Marker(
                          point: LatLng(photo.latitude!, photo.longitude!),
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pathColor,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
                // Transport icon (moving marker) — uses the same
                // _currentIconPosition as the polyline tip for perfect sync.
                if ((_isPreviewPlaying || _isExporting) &&
                    _currentIconPosition != null &&
                    _progressAlongPath > 0)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentIconPosition!,
                        width: 40,
                        height: 40,
                        child: _TransportIcon(
                          mode: _transportMode,
                          bearing: _bearingAtProgress(),
                          color: pathColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Photo popup overlay
          if (_currentPopupPhoto != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: Image.file(
                            File(_currentPopupPhoto!.resolvedFilePath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_currentPopupPhoto!.locationName != null)
                              Text(
                                _currentPopupPhoto!.locationName!,
                                style: AppTextStyles.subtitle2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (_currentPopupPhoto!.dateTaken != null)
                              Text(
                                _currentPopupPhoto!.dateTaken!.formatted,
                                style: AppTextStyles.caption,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Play/pause overlay
          if (!_isExporting)
            Positioned(
              top: (_routeError != null && !_isFetchingRoute) ? 48 : 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'preview_play',
                    onPressed:
                        _isFetchingRoute
                            ? null
                            : (_isPreviewPlaying
                                ? _stopPreview
                                : _startPreview),
                    child: Icon(
                      _isPreviewPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  // Re-center button — shown when user has panned away
                  if (_isPreviewPlaying && !_cameraFollowMode) ...[
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'recenter',
                      onPressed: () {
                        setState(() => _cameraFollowMode = true);
                      },
                      tooltip: 'Re-center on route',
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ],
              ),
            ),

          // Route loading overlay
          if (_isFetchingRoute)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Calculating route...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Route error banner
          if (_routeError != null && !_isFetchingRoute)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.orange.shade700,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Route unavailable — using straight lines',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchRoute,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export Settings',
            style: AppTextStyles.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Waypoint reorder button
          if (_geoPhotos.length >= 2 && !_isExporting && !_isPreviewPlaying)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _showReorderSheet,
                icon: const Icon(Icons.reorder_rounded, size: 18),
                label: Text('Reorder Waypoints (${_geoPhotos.length} stops)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),

          // Transport mode selector
          Row(
            children: [
              const Icon(Icons.route_rounded, size: 20),
              const SizedBox(width: 12),
              Text('Transport', style: AppTextStyles.body2),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        TransportMode.values.map((mode) {
                          return _TransportChip(
                            mode: mode,
                            isSelected: _transportMode == mode,
                            onTap:
                                (_isExporting || _isPreviewPlaying)
                                    ? null
                                    : () {
                                      setState(() => _transportMode = mode);
                                      _fetchRoute();
                                    },
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Speed slider
          Row(
            children: [
              const Icon(Icons.speed_rounded, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Animation Speed', style: AppTextStyles.body2),
                    Slider(
                      value: _animationSpeed,
                      min: 1,
                      max: 8,
                      divisions: 7,
                      label: '${_animationSpeed.toInt()}s',
                      onChanged:
                          _isExporting
                              ? null
                              : (v) => setState(() => _animationSpeed = v),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Color picker
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.palette_rounded, size: 20),
              const SizedBox(width: 12),
              Text('Path Color', style: AppTextStyles.body2),
              const SizedBox(width: 16),
              ...List.generate(
                AppTheme.polylineColors.length,
                (i) => GestureDetector(
                  onTap:
                      _isExporting
                          ? null
                          : () => setState(() => _selectedColorIndex = i),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.polylineColors[i],
                      shape: BoxShape.circle,
                      border:
                          i == _selectedColorIndex
                              ? Border.all(
                                color: colorScheme.onSurface,
                                width: 2,
                              )
                              : null,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Zoom level slider
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.zoom_in_rounded, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zoom Level', style: AppTextStyles.body2),
                    Slider(
                      value: _zoomLevel,
                      min: 6,
                      max: 16,
                      divisions: 10,
                      label: _zoomLevel.toInt().toString(),
                      onChanged:
                          _isExporting
                              ? null
                              : (v) => setState(() => _zoomLevel = v),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Frame quality slider
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.high_quality_rounded, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Smoothness', style: AppTextStyles.body2),
                        const Spacer(),
                        Text(
                          _framesPerSegment <= 5
                              ? 'Fast'
                              : _framesPerSegment <= 10
                              ? 'Normal'
                              : 'Smooth',
                          style: AppTextStyles.caption.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _framesPerSegment.toDouble(),
                      min: 5,
                      max: 20,
                      divisions: 3,
                      label: '$_framesPerSegment fps',
                      onChanged:
                          _isExporting
                              ? null
                              : (v) =>
                                  setState(() => _framesPerSegment = v.toInt()),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Estimated output info
          if (_waypoints.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Est. duration: ${((_waypoints.length - 1) * _animationSpeed).toStringAsFixed(0)}s '
                '| ${((_waypoints.length - 1) * _framesPerSegment)} frames '
                '| ${(_totalRouteDistance / 1000).toStringAsFixed(1)} km',
                style: AppTextStyles.caption.copyWith(color: Colors.grey[500]),
              ),
            ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Smooth easing'),
            subtitle: const Text('Ease in/out between waypoints'),
            value: _useEasing,
            onChanged:
                _isExporting ? null : (v) => setState(() => _useEasing = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show photo pop-ups'),
            value: _showPhotoPopups,
            onChanged:
                _isExporting
                    ? null
                    : (v) => setState(() => _showPhotoPopups = v),
          ),

          const SizedBox(height: 16),

          // Export button
          SizedBox(
            width: double.infinity,
            child:
                _isExporting
                    ? Column(
                      children: [
                        LinearProgressIndicator(
                          value: _exportProgress,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Capturing frames... ${(_exportProgress * 100).toInt()}%',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    )
                    : ElevatedButton.icon(
                      onPressed:
                          (_isFetchingRoute || _routedPath.length < 2)
                              ? null
                              : _exportVideo,
                      icon: const Icon(Icons.movie_creation_rounded),
                      label: const Text('Export Journey'),
                    ),
          ),

          // Share button
          if (_exportedFilePath != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _shareVideo,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────────

/// Animated transport icon marker — rotates based on bearing/heading.
class _TransportIcon extends StatelessWidget {
  final TransportMode mode;
  final double bearing; // radians
  final Color color;

  const _TransportIcon({
    required this.mode,
    required this.bearing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: bearing,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(mode.icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Selectable transport mode chip.
class _TransportChip extends StatelessWidget {
  final TransportMode mode;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TransportChip({
    required this.mode,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(mode.label),
        avatar: Icon(mode.icon, size: 16),
        onSelected: onTap != null ? (_) => onTap!() : null,
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Shallow equality check for LatLng lists.
bool _listEquals(List<LatLng> a, List<LatLng> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
      return false;
    }
  }
  return true;
}
