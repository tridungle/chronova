import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/vertical_timeline.dart';
import 'widgets/horizontal_timeline.dart';

/// Main timeline view with vertical/horizontal toggle.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVertical = ref.watch(timelineVerticalProvider);
    final timelineDays = ref.watch(timelineDaysProvider);
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          // Search
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
          // Toggle between vertical and horizontal
          IconButton(
            onPressed: () {
              ref.read(timelineVerticalProvider.notifier).state = !isVertical;
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isVertical
                    ? Icons.view_column_rounded
                    : Icons.view_agenda_rounded,
                key: ValueKey(isVertical),
              ),
            ),
            tooltip: isVertical ? 'Horizontal view' : 'Vertical view',
          ),
          IconButton(
            onPressed: () => context.push('/export'),
            icon: const Icon(Icons.movie_creation_outlined),
            tooltip: 'Export video',
          ),
        ],
      ),
      body: timelineDays.when(
        data: (days) {
          if (days.isEmpty) {
            return _EmptyTimeline(onImport: () => context.push('/import'));
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child:
                isVertical
                    ? VerticalTimeline(
                      key: const ValueKey('vertical'),
                      days: days,
                    )
                    : HorizontalTimeline(
                      key: const ValueKey('horizontal'),
                      days: days,
                    ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load timeline',
                    style: AppTextStyles.subtitle1,
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), style: AppTextStyles.caption),
                ],
              ),
            ),
      ),
    );
  }
}

/// Empty state when no photos are imported yet.
class _EmptyTimeline extends StatelessWidget {
  final VoidCallback onImport;

  const _EmptyTimeline({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 56,
                    color: context.colorScheme.primary,
                  ),
                )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 24),
            Text(
              'Your Timeline Awaits',
              style: AppTextStyles.headline2.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 12),
            Text(
              'Import photos to see them beautifully\narranged on your personal timeline.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2.copyWith(color: Colors.grey),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
            const SizedBox(height: 32),
            ElevatedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Import Photos'),
                )
                .animate()
                .fadeIn(delay: 600.ms, duration: 600.ms)
                .slideY(begin: 0.3, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
