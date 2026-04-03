import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/models.dart';
import '../timeline/widgets/vertical_timeline.dart';

/// Detail screen for a single trip — shows timeline + photos.
class TripDetailScreen extends ConsumerWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(tripId));
    final timelineDays = ref.watch(tripTimelineDaysProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: trip.when(
          data: (t) => Text(t?.name ?? 'Trip'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Trip'),
        ),
        actions: [
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
      body: timelineDays.when(
        data: (days) {
          if (days.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No photos in this trip',
                    style: AppTextStyles.subtitle1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import photos and assign them to this trip.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            );
          }
          return VerticalTimeline(days: days);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
    );
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
}
