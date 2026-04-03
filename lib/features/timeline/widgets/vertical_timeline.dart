import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/models.dart';
import '../../photo_detail/photo_detail_screen.dart';

/// A beautiful vertical timeline showing photos grouped by day.
class VerticalTimeline extends StatelessWidget {
  final List<TimelineDay> days;

  const VerticalTimeline({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return _TimelineItem(
          day: day,
          isFirst: index == 0,
          isLast: index == days.length - 1,
          index: index,
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TimelineDay day;
  final bool isFirst;
  final bool isLast;
  final int index;

  const _TimelineItem({
    required this.day,
    required this.isFirst,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;

    return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline rail (left side)
              SizedBox(
                width: 60,
                child: Column(
                  children: [
                    // Top connector line
                    if (!isFirst)
                      Container(
                        width: 2,
                        height: 16,
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    // Dot
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary,
                        border: Border.all(
                          color:
                              isDark ? const Color(0xFF1E1E2E) : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    // Bottom connector line
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                  ],
                ),
              ),

              // Content card (right side)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _DayCard(day: day),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: (80 * index).clamp(0, 800)),
          duration: 500.ms,
        )
        .slideX(
          begin: 0.1,
          delay: Duration(milliseconds: (80 * index).clamp(0, 800)),
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Card showing a day's photos, location, and notes.
///
/// Layout for multi-location days:
///   - Date + total photo count header
///   - Location sub-groups, each with: label + mood, thumbnail strip, note
///   (No full-day collage — avoids visual duplication)
///
/// Layout for single-location days:
///   - Date + mood + photo count + location
///   - Photo collage (all photos)
///   - Note preview
class _DayCard extends StatelessWidget {
  final TimelineDay day;

  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;
    final primaryPhoto = day.primaryPhoto;

    // Guard against empty photo days (should not happen in practice)
    if (primaryPhoto == null || day.photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + count header — always at top, above the collage
          _buildDateHeader(
            colorScheme,
            showLocation: !day.hasMultipleLocations,
          ),

          // Multi-location days: skip the full-day collage to avoid showing
          // the same photos twice (once in collage, again in sub-groups).
          // Single-location days: show the collage as usual.
          if (!day.hasMultipleLocations) ...[
            if (day.photos.length == 1)
              _SinglePhoto(photo: primaryPhoto, allPhotos: day.photos)
            else
              _PhotoCollage(photos: day.photos),
          ],

          // If there are multiple locations, show sub-groups (each with
          // its own thumbnail strip) instead of a single combined collage.
          if (day.hasMultipleLocations)
            ..._buildLocationSubGroups(context, colorScheme, isDark)
          else if (day.note != null && day.note!.isNotEmpty)
            // Single location — just the note preview below collage
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Text(
                day.note!,
                style: AppTextStyles.body2.copyWith(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  /// Date header with mood, formatted date, photo count badge, and optional
  /// location row. Placed at the top of the card, above the photo collage.
  Widget _buildDateHeader(
    ColorScheme colorScheme, {
    required bool showLocation,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!day.hasMultipleLocations && day.mood != null) ...[
                Text(day.mood!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  day.date.formattedLong,
                  style: AppTextStyles.subtitle2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${day.photos.length} photo${day.photos.length > 1 ? 's' : ''}',
                  style: AppTextStyles.label.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          // Location (only for single-location days)
          if (showLocation && day.locationName != null) ...[
            const SizedBox(height: 6),
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
                    day.locationName!,
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
    );
  }

  /// Build location sub-group widgets (header + thumbnails + note) for
  /// days that span multiple locations. Does NOT include the date header
  /// (that is rendered separately above the collage).
  List<Widget> _buildLocationSubGroups(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final widgets = <Widget>[];

    for (int i = 0; i < day.locationGroups.length; i++) {
      final group = day.locationGroups[i];
      if (group.photos.isEmpty) continue;

      // Divider between groups (not before the first)
      if (i > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(
              height: 16,
              thickness: 0.5,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        );
      }

      // Location label + mood emoji + photo count
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Row(
            children: [
              Icon(
                group.isUnknown
                    ? Icons.location_off_rounded
                    : Icons.location_on_rounded,
                size: 15,
                color: group.isUnknown ? Colors.grey[400] : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  group.label,
                  style: AppTextStyles.subtitle2.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        group.isUnknown
                            ? Colors.grey[500]
                            : colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (group.mood != null) ...[
                Text(group.mood!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${group.photos.length}',
                  style: AppTextStyles.label.copyWith(
                    color: colorScheme.primary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Horizontal thumbnail strip for this location group
      widgets.add(
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            itemCount: group.photos.length.clamp(0, 10),
            itemBuilder: (ctx, j) {
              final photo = group.photos[j];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder:
                          (_) => PhotoDetailScreen(
                            photos: List.from(day.photos),
                            initialIndex: day.photos
                                .indexOf(photo)
                                .clamp(0, day.photos.length - 1),
                          ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Hero(
                    tag: 'photo_${photo.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Image.file(
                          File(photo.resolvedFilePath),
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  Container(color: Colors.grey[300]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Note preview for this location group
      if (group.note != null && group.note!.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Text(
              group.note!,
              style: AppTextStyles.body2.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    // Bottom padding
    widgets.add(const SizedBox(height: 10));
    return widgets;
  }
}

class _SinglePhoto extends StatelessWidget {
  final Photo photo;
  final List<Photo> allPhotos;

  const _SinglePhoto({required this.photo, required this.allPhotos});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => PhotoDetailScreen(
                  photos: List.from(allPhotos),
                  initialIndex: allPhotos
                      .indexOf(photo)
                      .clamp(0, allPhotos.length - 1),
                ),
          ),
        );
      },
      child: Hero(
        tag: 'photo_${photo.id}',
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.file(
            File(photo.resolvedFilePath),
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image_rounded, size: 48),
                ),
          ),
        ),
      ),
    );
  }
}

/// Shows up to 4 photos in a grid collage.
class _PhotoCollage extends StatelessWidget {
  final List<Photo> photos;

  const _PhotoCollage({required this.photos});

  @override
  Widget build(BuildContext context) {
    final displayPhotos = photos.take(4).toList();
    final remaining = photos.length - 4;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(child: _buildGrid(displayPhotos, remaining)),
    );
  }

  Widget _buildGrid(List<Photo> displayPhotos, int remaining) {
    if (displayPhotos.length == 2) {
      return Row(
        children: [
          Expanded(child: _gridImage(displayPhotos[0])),
          const SizedBox(width: 2),
          Expanded(child: _gridImage(displayPhotos[1])),
        ],
      );
    }

    if (displayPhotos.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: _gridImage(displayPhotos[0])),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _gridImage(displayPhotos[1])),
                const SizedBox(height: 2),
                Expanded(child: _gridImage(displayPhotos[2])),
              ],
            ),
          ),
        ],
      );
    }

    // 4+ photos
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: _gridImage(displayPhotos[0])),
              const SizedBox(height: 2),
              Expanded(child: _gridImage(displayPhotos[2])),
            ],
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _gridImage(displayPhotos[1])),
              const SizedBox(height: 2),
              Expanded(
                child:
                    remaining > 0
                        ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _gridImage(displayPhotos[3]),
                            Container(
                              color: Colors.black.withValues(alpha: 0.5),
                              child: Center(
                                child: Text(
                                  '+$remaining',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        : _gridImage(displayPhotos[3]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gridImage(Photo photo) {
    return Builder(
      builder:
          (context) => GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => PhotoDetailScreen(
                        photos: List.from(photos),
                        initialIndex: photos
                            .indexOf(photo)
                            .clamp(0, photos.length - 1),
                      ),
                ),
              );
            },
            child: Hero(
              tag: 'photo_${photo.id}',
              child: SizedBox.expand(
                child: Image.file(
                  File(photo.resolvedFilePath),
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image_rounded),
                      ),
                ),
              ),
            ),
          ),
    );
  }
}
