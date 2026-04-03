import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Map view showing all photo locations with polyline connections.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _showPolyline = true;
  int _selectedPolylineColor = 0;
  double _polylineThickness = 3.0;
  Photo? _selectedPhoto;

  @override
  Widget build(BuildContext context) {
    final geoPhotos = ref.watch(geoPhotosProvider);
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          // Polyline toggle
          IconButton(
            onPressed: () => setState(() => _showPolyline = !_showPolyline),
            icon: Icon(
              _showPolyline ? Icons.timeline_rounded : Icons.timeline_outlined,
            ),
            tooltip: _showPolyline ? 'Hide path' : 'Show path',
          ),
          // Polyline color picker
          PopupMenuButton<int>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Path color',
            onSelected: (index) {
              setState(() => _selectedPolylineColor = index);
            },
            itemBuilder:
                (context) => List.generate(
                  AppTheme.polylineColors.length,
                  (index) => PopupMenuItem(
                    value: index,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.polylineColors[index],
                            shape: BoxShape.circle,
                            border:
                                index == _selectedPolylineColor
                                    ? Border.all(
                                      color: colorScheme.primary,
                                      width: 2,
                                    )
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_colorNames[index], style: AppTextStyles.body2),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
      body: geoPhotos.when(
        data: (photos) {
          if (photos.isEmpty) {
            return _EmptyMapState();
          }

          final points =
              photos
                  .where((p) => p.hasLocation)
                  .map((p) => LatLng(p.latitude!, p.longitude!))
                  .toList();

          // Calculate bounds
          final bounds = LatLngBounds.fromPoints(points);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: bounds.center,
                  initialZoom: 5,
                  onTap: (_, __) {
                    setState(() => _selectedPhoto = null);
                  },
                ),
                children: [
                  // Tile layer
                  TileLayer(
                    urlTemplate:
                        isDark
                            ? AppConstants.cartoDarkTileUrl
                            : AppConstants.cartoLightTileUrl,
                    userAgentPackageName: 'com.chronova.app',
                    maxZoom: 19,
                  ),

                  // Polyline layer
                  if (_showPolyline && points.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          strokeWidth: _polylineThickness,
                          color: AppTheme.polylineColors[_selectedPolylineColor]
                              .withValues(alpha: 0.8),
                          borderStrokeWidth: 1,
                          borderColor: AppTheme
                              .polylineColors[_selectedPolylineColor]
                              .withValues(alpha: 0.3),
                        ),
                      ],
                    ),

                  // Markers
                  MarkerLayer(
                    markers:
                        photos.where((p) => p.hasLocation).map((photo) {
                          return Marker(
                            point: LatLng(photo.latitude!, photo.longitude!),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedPhoto = photo);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        _selectedPhoto?.id == photo.id
                                            ? colorScheme.primary
                                            : Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.file(
                                    File(photo.filePath),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Container(
                                          color: colorScheme.primary,
                                          child: const Icon(
                                            Icons.photo,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),

              // Selected photo popup
              if (_selectedPhoto != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _PhotoPopup(
                    photo: _selectedPhoto!,
                    onClose: () => setState(() => _selectedPhoto = null),
                  ),
                ),

              // Thickness slider (bottom-left)
              Positioned(
                bottom: _selectedPhoto != null ? 200 : 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.line_weight_rounded, size: 18),
                      SizedBox(
                        height: 100,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: _polylineThickness,
                            min: 1,
                            max: 8,
                            onChanged: (v) {
                              setState(() => _polylineThickness = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fit bounds button
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'fit_bounds',
                  onPressed: () {
                    if (points.length >= 2) {
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(50),
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.fit_screen_rounded, size: 20),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading map data: $e')),
      ),
    );
  }

  static const _colorNames = [
    'Blue',
    'Red',
    'Green',
    'Orange',
    'Purple',
    'Cyan',
  ];
}

class _EmptyMapState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No locations yet',
            style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Import photos with GPS data to see\nthem on the map.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Popup card showing the selected photo's details.
class _PhotoPopup extends StatelessWidget {
  final Photo photo;
  final VoidCallback onClose;

  const _PhotoPopup({required this.photo, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image_rounded, size: 40),
                    ),
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (photo.dateTaken != null)
                        Text(
                          photo.dateTaken!.formattedFull,
                          style: AppTextStyles.subtitle2,
                        ),
                      if (photo.locationName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                photo.locationName!,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (photo.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          photo.note!,
                          style: AppTextStyles.body2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
