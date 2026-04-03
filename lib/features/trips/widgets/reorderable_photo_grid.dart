import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/photo.dart';
import '../../photo_detail/photo_detail_screen.dart';

/// A reorderable list of photos for manual ordering within a trip.
class ReorderablePhotoGrid extends StatefulWidget {
  final List<Photo> photos;
  final ValueChanged<List<Photo>> onReorder;

  const ReorderablePhotoGrid({
    super.key,
    required this.photos,
    required this.onReorder,
  });

  @override
  State<ReorderablePhotoGrid> createState() => _ReorderablePhotoGridState();
}

class _ReorderablePhotoGridState extends State<ReorderablePhotoGrid> {
  late List<Photo> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
  }

  @override
  void didUpdateWidget(covariant ReorderablePhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos != widget.photos) {
      _photos = List.from(widget.photos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    if (_photos.isEmpty) {
      return const Center(child: Text('No photos to reorder.'));
    }

    return Column(
      children: [
        // Header hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: colorScheme.primary.withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Long press and drag to reorder photos',
                style: AppTextStyles.caption.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevationValue = Tween<double>(
                    begin: 0,
                    end: 8,
                  ).evaluate(animation);
                  return Material(
                    elevation: elevationValue,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemCount: _photos.length,
            onReorder: (oldIndex, newIndex) {
              HapticFeedback.mediumImpact();
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _photos.removeAt(oldIndex);
                _photos.insert(newIndex, item);
              });
              widget.onReorder(_photos);
            },
            itemBuilder: (context, index) {
              final photo = _photos[index];
              return _ReorderablePhotoTile(
                key: ValueKey(photo.id),
                photo: photo,
                index: index,
                allPhotos: _photos,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single photo tile in the reorderable list.
class _ReorderablePhotoTile extends StatelessWidget {
  final Photo photo;
  final int index;
  final List<Photo> allPhotos;

  const _ReorderablePhotoTile({
    super.key,
    required this.photo,
    required this.index,
    required this.allPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => PhotoDetailScreen(
                      photos: List.from(allPhotos),
                      initialIndex: index,
                    ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Order number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: AppTextStyles.label.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.file(
                      File(photo.resolvedFilePath),
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image_rounded,
                              size: 24,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (photo.dateTaken != null)
                        Text(
                          photo.dateTaken!.formattedFull,
                          style: AppTextStyles.subtitle2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (photo.locationName != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 2),
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
                    ],
                  ),
                ),
                // Drag handle
                Icon(Icons.drag_handle_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
