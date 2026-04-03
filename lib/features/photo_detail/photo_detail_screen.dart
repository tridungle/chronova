import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/models.dart';
import '../journal/journal_editor.dart';

/// Full-screen photo viewer with zoom/pan, EXIF info, journal, and delete.
///
/// Accepts a list of photos and a starting index to allow swiping.
class PhotoDetailScreen extends ConsumerStatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const PhotoDetailScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<Photo> _photos; // Local mutable copy of the photo list
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _currentIndex = widget.initialIndex.clamp(0, _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Photo get _currentPhoto => _photos[_currentIndex];

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  Future<void> _deletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Photo'),
            content: const Text(
              'This will permanently remove this photo from Chronova. '
              'The original file on your device will not be affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();
    final deletedTripId = _currentPhoto.tripId;
    await ref.read(photoRepositoryProvider).delete(_currentPhoto.id);

    // Guard: the widget may have been disposed during the async gap.
    if (!mounted) return;

    // Refresh providers
    ref.invalidate(allPhotosProvider);
    ref.invalidate(timelineDaysProvider);
    ref.invalidate(geoPhotosProvider);
    ref.invalidate(tripsProvider);
    ref.invalidate(photoCountProvider);
    ref.invalidate(journalEntriesProvider);

    // Invalidate trip-specific providers if the photo belonged to a trip
    if (deletedTripId != null) {
      ref.invalidate(tripPhotosProvider(deletedTripId));
      ref.invalidate(tripTimelineDaysProvider(deletedTripId));
      ref.invalidate(tripPhotoCountProvider(deletedTripId));
    }

    // If this was the only photo, pop the screen
    if (_photos.length <= 1) {
      Navigator.pop(context, true);
      return;
    }

    // Remove photo from local list and adjust index
    setState(() {
      _photos.removeAt(_currentIndex);
      if (_currentIndex >= _photos.length) {
        _currentIndex = _photos.length - 1;
      }
      // Recreate page controller to sync with new list length
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentIndex);
    });

    context.showSnackBar('Photo deleted');
  }

  void _showExifInfo() {
    final photo = _currentPhoto;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExifInfoSheet(photo: photo),
    );
  }

  Future<void> _openJournal() async {
    await JournalEditor.show(
      context,
      photo: _currentPhoto,
      tripId: _currentPhoto.tripId,
      date: _currentPhoto.dateTaken ?? DateTime.now(),
    );

    // Refresh the local photo object from DB so the overlay shows updated
    // note/mood/tags without requiring a manual back+re-enter.
    if (!mounted) return;
    final refreshed = await ref
        .read(photoRepositoryProvider)
        .getById(_currentPhoto.id);
    if (refreshed != null && mounted) {
      setState(() {
        _photos[_currentIndex] = refreshed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo gallery with zoom/pan
          GestureDetector(
            onTap: _toggleOverlay,
            child: PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: _photos.length,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _currentIndex = index);
              },
              builder: (context, index) {
                final photo = _photos[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: FileImage(File(photo.resolvedFilePath)),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(
                    tag: 'photo_${photo.id}',
                  ),
                  errorBuilder:
                      (ctx, error, stack) => const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                );
              },
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder:
                  (_, event) => Center(
                    child: CircularProgressIndicator(
                      value:
                          event == null
                              ? null
                              : event.cumulativeBytesLoaded /
                                  (event.expectedTotalBytes ?? 1),
                      color: Colors.white54,
                    ),
                  ),
            ),
          ),

          // Top overlay — back button + actions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: Colors.white,
                          tooltip: 'Back',
                        ),
                        const Spacer(),
                        // Page indicator
                        if (_photos.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${_photos.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: _deletePhoto,
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: Colors.red[300],
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom overlay — photo info + action buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Date
                          if (_currentPhoto.dateTaken != null)
                            Text(
                              _currentPhoto.dateTaken!.formattedFull,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                          // Location
                          if (_currentPhoto.locationName != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _currentPhoto.locationName!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Note preview
                          if (_currentPhoto.note != null &&
                              _currentPhoto.note!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (_currentPhoto.mood != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text(
                                      _currentPhoto.mood!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    _currentPhoto.note!,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ActionButton(
                                icon: Icons.info_outline_rounded,
                                label: 'Info',
                                onTap: _showExifInfo,
                              ),
                              _ActionButton(
                                icon: Icons.edit_note_rounded,
                                label: 'Journal',
                                onTap: _openJournal,
                              ),
                              if (_currentPhoto.hasLocation)
                                _ActionButton(
                                  icon: Icons.map_rounded,
                                  label: 'Map',
                                  onTap: () {
                                    Navigator.pop(context);
                                    // Navigate to map tab via GoRouter
                                    GoRouter.of(context).go('/map');
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EXIF Info Sheet ───────────────────────────────────────────

class _ExifInfoSheet extends StatelessWidget {
  final Photo photo;

  const _ExifInfoSheet({required this.photo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    // Calculate file size string
    String fileSize = 'Unknown';
    if (photo.fileSize != null) {
      final kb = photo.fileSize! / 1024;
      if (kb > 1024) {
        fileSize = '${(kb / 1024).toStringAsFixed(1)} MB';
      } else {
        fileSize = '${kb.toStringAsFixed(0)} KB';
      }
    }

    final infoItems = <_InfoRow>[
      if (photo.dateTaken != null)
        _InfoRow('Date Taken', photo.dateTaken!.formattedFull),
      if (photo.locationName != null) _InfoRow('Location', photo.locationName!),
      if (photo.latitude != null && photo.longitude != null)
        _InfoRow(
          'Coordinates',
          '${photo.latitude!.toStringAsFixed(6)}, '
              '${photo.longitude!.toStringAsFixed(6)}',
        ),
      if (photo.altitude != null)
        _InfoRow('Altitude', '${photo.altitude!.toStringAsFixed(1)} m'),
      if (photo.cameraModel != null) _InfoRow('Camera', photo.cameraModel!),
      if (photo.width != null && photo.height != null)
        _InfoRow('Dimensions', '${photo.width} x ${photo.height}'),
      _InfoRow('File Size', fileSize),
      if (photo.tags != null && photo.tags!.isNotEmpty)
        _InfoRow('Tags', photo.tagList.join(', ')),
      _InfoRow('File', photo.filePath.split('/').last),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text('Photo Details', style: AppTextStyles.headline3),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: infoItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = infoItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          item.label,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(item.value, style: AppTextStyles.body2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
