import 'dart:io';
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
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_retry_widget.dart';
import '../../data/models/models.dart';

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
/// Renders a fly-along animation on the map with photo pop-ups.
/// Captures frames via [RepaintBoundary] and encodes them into an
/// animated GIF using the pure-Dart `image` package.
/// No native ffmpeg binary is required.
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
  double _animationSpeed = 3.0; // seconds per segment
  int _selectedColorIndex = 0;
  final double _polylineThickness = 4.0;
  bool _showPhotoPopups = true;
  bool _showLocationLabels = true;
  int _framesPerSegment = 10; // 5=fast/small, 10=default, 20=smooth/large
  double _zoomLevel = 12.0; // map zoom during fly-along
  bool _useEasing = true; // ease in/out between waypoints

  // Map state
  final MapController _mapController = MapController();
  int _currentSegment = 0;
  Photo? _currentPopupPhoto;

  // Data
  List<Photo> _geoPhotos = [];
  List<LatLng> _routePoints = [];

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

  void _onAnimationTick() {
    if (_routePoints.length < 2) return;

    final totalSegments = _routePoints.length - 1;
    final progress = _flyController.value;
    final segmentProgress = progress * totalSegments;
    final segmentIndex = segmentProgress.floor().clamp(0, totalSegments - 1);
    var localProgress = segmentProgress - segmentIndex;

    // Apply easing curve within each segment for smoother transitions
    if (_useEasing) {
      localProgress = Curves.easeInOutCubic.transform(
        localProgress.clamp(0.0, 1.0),
      );
    }

    // Interpolate position between waypoints
    final from = _routePoints[segmentIndex];
    final to =
        _routePoints[(segmentIndex + 1).clamp(0, _routePoints.length - 1)];
    final currentLat =
        from.latitude + (to.latitude - from.latitude) * localProgress;
    final currentLng =
        from.longitude + (to.longitude - from.longitude) * localProgress;

    _mapController.move(LatLng(currentLat, currentLng), _zoomLevel);

    // Show popup when arriving at a new waypoint
    if (segmentIndex != _currentSegment) {
      if (!mounted) return;
      setState(() {
        _currentSegment = segmentIndex;
        if (_showPhotoPopups && segmentIndex < _geoPhotos.length) {
          _currentPopupPhoto = _geoPhotos[segmentIndex];
        }
      });
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (!mounted) return;
      setState(() {
        _isPreviewPlaying = false;
        _currentPopupPhoto = null;
      });
    }
  }

  void _startPreview() {
    if (_routePoints.length < 2) return;

    final totalDuration = (_animationSpeed * (_routePoints.length - 1)).toInt();
    _flyController.duration = Duration(seconds: totalDuration);
    _flyController.reset();

    setState(() {
      _isPreviewPlaying = true;
      _currentSegment = 0;
      _currentPopupPhoto = null;
    });

    _mapController.move(_routePoints.first, _zoomLevel);
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
  ///
  /// Steps:
  ///   1. Walk the animation from 0 → 1 in discrete steps.
  ///   2. For each step, move the map and capture a frame.
  ///   3. Encode all frames into an animated GIF with the `image` package.
  Future<void> _exportVideo() async {
    if (_routePoints.length < 2) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportedFilePath = null;
    });

    try {
      // Number of frames to capture — configurable for smoothness vs file size
      final totalSegments = _routePoints.length - 1;
      final totalFrames = totalSegments * _framesPerSegment;

      // Frame duration in centiseconds (100cs = 1 second)
      final durationCs = ((_animationSpeed / _framesPerSegment) * 100).round();
      final gifEncoder = img.GifEncoder(delay: durationCs);

      for (int i = 0; i <= totalFrames; i++) {
        final t = i / totalFrames; // 0 → 1
        final segF = t * totalSegments;
        final seg = segF.floor().clamp(0, totalSegments - 1);
        var local = segF - seg;

        // Apply easing for smoother camera motion per segment
        if (_useEasing) {
          local = Curves.easeInOutCubic.transform(local.clamp(0.0, 1.0));
        }

        final from = _routePoints[seg];
        final to = _routePoints[(seg + 1).clamp(0, _routePoints.length - 1)];
        final lat = from.latitude + (to.latitude - from.latitude) * local;
        final lng = from.longitude + (to.longitude - from.longitude) * local;

        // Move the map
        _mapController.move(LatLng(lat, lng), _zoomLevel);

        // Update popup
        if (_showPhotoPopups &&
            seg < _geoPhotos.length &&
            seg != _currentSegment) {
          if (!mounted) return;
          setState(() {
            _currentSegment = seg;
            _currentPopupPhoto = _geoPhotos[seg];
          });
        }

        // Wait for the map to render the new position
        await Future.delayed(const Duration(milliseconds: 80));

        // Capture frame and add to encoder
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

  // ─── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final geoPhotos = ref.watch(geoPhotosProvider);
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

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
          // Update data only when not animating/exporting to prevent stale references
          if (!_isPreviewPlaying && !_isExporting) {
            _geoPhotos = photos.where((p) => p.hasLocation).toList();
            _routePoints =
                _geoPhotos
                    .map((p) => LatLng(p.latitude!, p.longitude!))
                    .toList();
          }

          if (_geoPhotos.isEmpty) {
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
                    style: AppTextStyles.headline3.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import photos with GPS data first\nto create a travel video.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.grey[500],
                    ),
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

          final bounds = LatLngBounds.fromPoints(_routePoints);

          return Column(
            children: [
              // Map preview wrapped in RepaintBoundary for frame capture
              Expanded(
                flex: 3,
                child: RepaintBoundary(
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
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  isDark
                                      ? AppConstants.cartoDarkTileUrl
                                      : AppConstants.cartoLightTileUrl,
                              userAgentPackageName: 'com.chronova.app',
                              errorImage: _kTransparentTile,
                              evictErrorTileStrategy:
                                  EvictErrorTileStrategy.dispose,
                            ),
                            if (_routePoints.length >= 2)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _routePoints,
                                    strokeWidth: _polylineThickness,
                                    color:
                                        AppTheme
                                            .polylineColors[_selectedColorIndex],
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers:
                                  _geoPhotos.map((photo) {
                                    return Marker(
                                      point: LatLng(
                                        photo.latitude!,
                                        photo.longitude!,
                                      ),
                                      width: 24,
                                      height: 24,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              AppTheme
                                                  .polylineColors[_selectedColorIndex],
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
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
                                        File(_currentPopupPhoto!.filePath),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_currentPopupPhoto!.locationName !=
                                            null)
                                          Text(
                                            _currentPopupPhoto!.locationName!,
                                            style: AppTextStyles.subtitle2,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (_currentPopupPhoto!.dateTaken !=
                                            null)
                                          Text(
                                            _currentPopupPhoto!
                                                .dateTaken!
                                                .formatted,
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
                          top: 16,
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'preview_play',
                            onPressed:
                                _isPreviewPlaying
                                    ? _stopPreview
                                    : _startPreview,
                            child: Icon(
                              _isPreviewPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Settings panel
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),

                      // Speed slider
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Animation Speed',
                                  style: AppTextStyles.body2,
                                ),
                                Slider(
                                  value: _animationSpeed,
                                  min: 1,
                                  max: 8,
                                  divisions: 7,
                                  label: '${_animationSpeed.toInt()}s',
                                  onChanged:
                                      _isExporting
                                          ? null
                                          : (v) => setState(
                                            () => _animationSpeed = v,
                                          ),
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
                                      : () => setState(
                                        () => _selectedColorIndex = i,
                                      ),
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

                      // Toggles
                      const SizedBox(height: 16),

                      // Zoom level slider
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
                                          : (v) =>
                                              setState(() => _zoomLevel = v),
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
                                    Text(
                                      'Smoothness',
                                      style: AppTextStyles.body2,
                                    ),
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
                                          : (v) => setState(
                                            () => _framesPerSegment = v.toInt(),
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Estimated output info
                      if (_routePoints.length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'Est. duration: ${((_routePoints.length - 1) * _animationSpeed).toStringAsFixed(0)}s '
                            '| ${((_routePoints.length - 1) * _framesPerSegment)} frames',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Smooth easing'),
                        subtitle: const Text('Ease in/out between waypoints'),
                        value: _useEasing,
                        onChanged:
                            _isExporting
                                ? null
                                : (v) => setState(() => _useEasing = v),
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show location labels'),
                        value: _showLocationLabels,
                        onChanged:
                            _isExporting
                                ? null
                                : (v) =>
                                    setState(() => _showLocationLabels = v),
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
                                  onPressed: _exportVideo,
                                  icon: const Icon(
                                    Icons.movie_creation_rounded,
                                  ),
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
                ),
              ),
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
}
