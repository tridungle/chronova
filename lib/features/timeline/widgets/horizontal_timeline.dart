import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/models.dart';
import '../../photo_detail/photo_detail_screen.dart';

/// Horizontal scrollable timeline — cards scroll left/right.
class HorizontalTimeline extends StatefulWidget {
  final List<TimelineDay> days;

  const HorizontalTimeline({super.key, required this.days});

  @override
  State<HorizontalTimeline> createState() => _HorizontalTimelineState();
}

class _HorizontalTimelineState extends State<HorizontalTimeline> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      children: [
        // Top date strip
        Container(
          height: 80,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.days.length,
            itemBuilder: (context, index) {
              final day = widget.days[index];
              final isSelected = index == _currentPage;

              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  );
                  setState(() => _currentPage = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        isSelected
                            ? null
                            : Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                            ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.date.day}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : colorScheme.primary,
                        ),
                      ),
                      Text(
                        day.date.formatted
                            .split(' ')
                            .first, // Month abbreviation
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Page view for day cards
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: widget.days.length,
            itemBuilder: (context, index) {
              final day = widget.days[index];
              return _HorizontalDayCard(day: day, index: index);
            },
          ),
        ),

        // Page indicator — compact text for many pages, dots for few
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child:
              widget.days.length > 10
                  ? Text(
                    '${_currentPage + 1} / ${widget.days.length}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.days.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              index == _currentPage
                                  ? colorScheme.primary
                                  : colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}

class _HorizontalDayCard extends StatelessWidget {
  final TimelineDay day;
  final int index;

  const _HorizontalDayCard({required this.day, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = context.isDark;
    final primaryPhoto = day.primaryPhoto;

    // Guard against empty photo days
    if (primaryPhoto == null || day.photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main photo — takes most space
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PhotoDetailScreen(
                                photos: List.from(day.photos),
                                initialIndex: 0,
                              ),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'photo_${primaryPhoto.id}',
                          child: Image.file(
                            File(primaryPhoto.resolvedFilePath),
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    size: 48,
                                  ),
                                ),
                          ),
                        ),
                        // Gradient overlay at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Location badge(s)
                        if (day.hasMultipleLocations)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.explore_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${day.locationGroups.length} locations',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (day.locationName != null)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    day.locationName!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Photo count badge
                        if (day.photos.length > 1)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${day.photos.length} photos',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Location sub-groups with thumbnails — shown when
                // there are multiple locations on this day.
                // Wrapped in Expanded + SingleChildScrollView to prevent
                // vertical overflow when many location groups are present.
                if (day.hasMultipleLocations)
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildLocationThumbnailSections(
                          context,
                          colorScheme,
                          isDark,
                        ),
                      ),
                    ),
                  )
                else if (day.photos.length > 1)
                  // Single-location thumbnail strip (original)
                  _buildThumbnailStrip(day.photos),

                // Info section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!day.hasMultipleLocations &&
                              day.mood != null) ...[
                            Text(
                              day.mood!,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              day.date.formattedLong,
                              style: AppTextStyles.subtitle1.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!day.hasMultipleLocations &&
                          day.note != null &&
                          day.note!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          day.note!,
                          style: AppTextStyles.body2.copyWith(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.95, 0.95), duration: 500.ms);
  }

  /// Build a simple horizontal thumbnail strip for a single-location day.
  Widget _buildThumbnailStrip(List<Photo> photos) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: photos.length.clamp(0, 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => PhotoDetailScreen(
                        photos: List.from(photos),
                        initialIndex: i,
                      ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Hero(
                tag: i == 0 ? 'thumb_${photos[i].id}' : 'photo_${photos[i].id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.file(
                      File(photos[i].resolvedFilePath),
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(color: Colors.grey[300]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build location-labeled thumbnail sections for multi-location days.
  ///
  /// Each location group gets a label with mood, thumbnails, and note preview.
  List<Widget> _buildLocationThumbnailSections(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final sections = <Widget>[];

    for (int i = 0; i < day.locationGroups.length; i++) {
      final group = day.locationGroups[i];
      if (group.photos.isEmpty) continue;

      // Divider between groups (not before the first)
      if (i > 0) {
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              height: 8,
              thickness: 0.5,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        );
      }

      // Location label + mood + count
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            children: [
              Icon(
                group.isUnknown
                    ? Icons.location_off_rounded
                    : Icons.location_on_rounded,
                size: 12,
                color: group.isUnknown ? Colors.grey[400] : colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        group.isUnknown
                            ? Colors.grey[400]
                            : colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (group.mood != null) ...[
                Text(group.mood!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
              ],
              Text(
                '${group.photos.length}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );

      // Thumbnail strip
      sections.add(
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: group.photos.length.clamp(0, 8),
            itemBuilder: (ctx, j) {
              final photo = group.photos[j];
              final dayIndex = day.photos
                  .indexOf(photo)
                  .clamp(0, day.photos.length - 1);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder:
                          (_) => PhotoDetailScreen(
                            photos: List.from(day.photos),
                            initialIndex: dayIndex,
                          ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Image.file(
                        File(photo.resolvedFilePath),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(color: Colors.grey[300]),
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
        sections.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
            child: Text(
              group.note!,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    return sections;
  }
}
