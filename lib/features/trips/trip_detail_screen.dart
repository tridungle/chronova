import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/error_retry_widget.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../data/models/models.dart';
import '../timeline/widgets/vertical_timeline.dart';
import 'widgets/reorderable_photo_grid.dart';

/// Detail screen for a single trip — shows timeline + photos.
class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  bool _isReordering = false;

  String get tripId => widget.tripId;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(tripId));
    final timelineDays = ref.watch(tripTimelineDaysProvider(tripId));
    final tripPhotos = ref.watch(tripPhotosProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: trip.when(
          data: (t) => Text(t?.name ?? 'Trip'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Trip'),
        ),
        actions: [
          // Add photos to this trip
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            tooltip: 'Add photos',
            onSelected: (value) {
              if (value == 'import') {
                HapticFeedback.lightImpact();
                context.push('/import', extra: tripId);
              } else if (value == 'assign') {
                _showAssignPhotosSheet(context, ref);
              }
            },
            itemBuilder:
                (ctx) => [
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.add_photo_alternate_rounded),
                      title: Text('Import New Photos'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'assign',
                    child: ListTile(
                      leading: Icon(Icons.photo_library_rounded),
                      title: Text('Assign Existing Photos'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
          ),
          // Reorder toggle
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isReordering = !_isReordering);
            },
            icon: Icon(
              _isReordering
                  ? Icons.view_timeline_rounded
                  : Icons.reorder_rounded,
            ),
            tooltip: _isReordering ? 'Timeline view' : 'Reorder photos',
          ),
          IconButton(
            onPressed: () {
              final tripData = trip.valueOrNull;
              if (tripData != null) {
                _showEditTripDialog(context, ref, tripData);
              }
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit trip',
          ),
          IconButton(
            onPressed: () {
              final tripData = trip.valueOrNull;
              if (tripData != null) {
                _showDeleteTripDialog(context, ref, tripData);
              }
            },
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400]),
            tooltip: 'Delete trip',
          ),
        ],
      ),
      body:
          _isReordering
              ? _buildReorderView(tripPhotos)
              : _buildTimelineView(timelineDays),
    );
  }

  Widget _buildTimelineView(AsyncValue<List<TimelineDay>> timelineDays) {
    return timelineDays.when(
      data: (days) {
        if (days.isEmpty) {
          return _buildEmptyState();
        }
        return RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            ref.invalidate(tripTimelineDaysProvider(tripId));
            await ref.read(tripTimelineDaysProvider(tripId).future);
          },
          child: VerticalTimeline(days: days),
        );
      },
      loading: () => SkeletonLoaders.timeline(context),
      error:
          (e, _) => ErrorRetryWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(tripTimelineDaysProvider(tripId)),
          ),
    );
  }

  Widget _buildReorderView(AsyncValue<List<Photo>> tripPhotos) {
    return tripPhotos.when(
      data: (photos) {
        if (photos.isEmpty) {
          return _buildEmptyState();
        }
        return ReorderablePhotoGrid(
          photos: photos,
          onReorder: (reorderedPhotos) async {
            // Build a map of photo IDs to new sort orders
            final idToOrder = <String, int>{};
            for (int i = 0; i < reorderedPhotos.length; i++) {
              idToOrder[reorderedPhotos[i].id] = i;
            }
            // Persist to database
            await ref.read(photoRepositoryProvider).updateSortOrders(idToOrder);
            // Invalidate providers to refresh views
            ref.invalidate(tripPhotosProvider(tripId));
            ref.invalidate(tripTimelineDaysProvider(tripId));
            if (mounted) {
              context.showSnackBar('Photo order updated');
            }
          },
        );
      },
      loading: () => SkeletonLoaders.timeline(context),
      error:
          (e, _) => ErrorRetryWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(tripPhotosProvider(tripId)),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No photos in this trip', style: AppTextStyles.subtitle1),
          const SizedBox(height: 8),
          Text(
            'Import new photos or assign existing ones to this trip.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/import', extra: tripId);
            },
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Import Photos'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showAssignPhotosSheet(context, ref),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Assign Existing Photos'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to edit trip name and description.
  void _showEditTripDialog(BuildContext context, WidgetRef ref, Trip trip) {
    final nameController = TextEditingController(text: trip.name);
    final descController = TextEditingController(text: trip.description ?? '');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Trip'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Trip Name',
                    hintText: 'e.g., Japan 2024',
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'A short description of your trip',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 1,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final updated = trip.copyWith(
                    name: name,
                    description:
                        descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                    updatedAt: DateTime.now(),
                  );

                  await ref.read(tripRepositoryProvider).update(updated);
                  ref.invalidate(tripsProvider);
                  ref.invalidate(tripProvider(tripId));

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    context.showSnackBar('Trip updated');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    ).then((_) {
      nameController.dispose();
      descController.dispose();
    });
  }

  /// Show confirmation dialog to delete a trip.
  void _showDeleteTripDialog(BuildContext context, WidgetRef ref, Trip trip) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Trip'),
            content: Text(
              'Are you sure you want to delete "${trip.name}"?\n\n'
              'Photos assigned to this trip will be unassigned but not deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  // Unassign all photos from this trip first
                  final photos = await ref
                      .read(photoRepositoryProvider)
                      .getByTripId(tripId);
                  if (photos.isNotEmpty) {
                    await ref
                        .read(photoRepositoryProvider)
                        .removeFromTrip(photos.map((p) => p.id).toList());
                  }

                  // Delete the trip
                  await ref.read(tripRepositoryProvider).delete(tripId);

                  // Refresh providers
                  ref.invalidate(tripsProvider);
                  ref.invalidate(allPhotosProvider);
                  ref.invalidate(timelineDaysProvider);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    context.showSnackBar('Trip deleted');
                    context.pop(); // Go back to trips list
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Show bottom sheet to select and assign unassigned photos to this trip.
  void _showAssignPhotosSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssignPhotosSheet(tripId: tripId),
    ).then((_) {
      // Refresh trip data after assignment
      ref.invalidate(tripPhotosProvider(tripId));
      ref.invalidate(tripTimelineDaysProvider(tripId));
      ref.invalidate(tripPhotoCountProvider(tripId));
    });
  }
}

/// Bottom sheet that displays unassigned photos for selection and assignment.
class _AssignPhotosSheet extends ConsumerStatefulWidget {
  final String tripId;

  const _AssignPhotosSheet({required this.tripId});

  @override
  ConsumerState<_AssignPhotosSheet> createState() => _AssignPhotosSheetState();
}

class _AssignPhotosSheetState extends ConsumerState<_AssignPhotosSheet> {
  final _selected = <String>{};
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final unassigned = ref.watch(unassignedPhotosProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title + action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Assign Photos',
                      style: AppTextStyles.headline3,
                    ),
                  ),
                  if (_selected.isNotEmpty && !_isAssigning)
                    TextButton.icon(
                      onPressed: _assignSelected,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Assign (${_selected.length})'),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Photo grid
            Expanded(
              child: unassigned.when(
                data: (photos) {
                  if (photos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No unassigned photos',
                              style: AppTextStyles.subtitle1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Import photos first, then assign them here.',
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                    itemCount: photos.length,
                    itemBuilder: (ctx, index) {
                      final photo = photos[index];
                      final isSelected = _selected.contains(photo.id);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selected.remove(photo.id);
                            } else {
                              _selected.add(photo.id);
                            }
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(photo.resolvedFilePath),
                                fit: BoxFit.cover,
                                cacheWidth: 200,
                                errorBuilder:
                                    (_, __, ___) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.broken_image_rounded,
                                      ),
                                    ),
                              ),
                            ),
                            // Selection overlay
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    isSelected
                                        ? Border.all(
                                          color: colorScheme.primary,
                                          width: 3,
                                        )
                                        : null,
                                color:
                                    isSelected
                                        ? colorScheme.primary.withValues(
                                          alpha: 0.2,
                                        )
                                        : Colors.transparent,
                              ),
                            ),
                            // Checkmark
                            if (isSelected)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (e, _) => Center(child: Text('Error loading photos: $e')),
              ),
            ),

            // Select all / assign bar
            if ((unassigned.valueOrNull ?? []).isNotEmpty)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          final photos = unassigned.valueOrNull ?? [];
                          setState(() {
                            if (_selected.length == photos.length) {
                              _selected.clear();
                            } else {
                              _selected
                                ..clear()
                                ..addAll(photos.map((p) => p.id));
                            }
                          });
                        },
                        child: Text(
                          _selected.length ==
                                  (unassigned.valueOrNull ?? []).length
                              ? 'Deselect All'
                              : 'Select All',
                        ),
                      ),
                      const Spacer(),
                      if (_selected.isNotEmpty)
                        ElevatedButton(
                          onPressed: _isAssigning ? null : _assignSelected,
                          child:
                              _isAssigning
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    'Assign ${_selected.length} photo${_selected.length == 1 ? '' : 's'}',
                                  ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _assignSelected() async {
    if (_selected.isEmpty) return;

    setState(() => _isAssigning = true);

    try {
      await ref
          .read(photoRepositoryProvider)
          .assignToTrip(_selected.toList(), widget.tripId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assigned ${_selected.length} photo${_selected.length == 1 ? '' : 's'} to trip',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to assign photos: $e')));
      }
    }
  }
}
