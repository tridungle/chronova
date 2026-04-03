import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/models.dart';

/// Screen listing all trips.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            onPressed: () => _showCreateTripDialog(context, ref),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New trip',
          ),
        ],
      ),
      body: trips.when(
        data: (tripList) {
          if (tripList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.luggage_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No trips yet',
                    style: AppTextStyles.headline3.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a trip to group your photos\nby destination or journey.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateTripDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Trip'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tripList.length,
            itemBuilder: (context, index) {
              final trip = tripList[index];
              return _TripCard(trip: trip, index: index)
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 60 * index),
                    duration: 400.ms,
                  )
                  .slideY(
                    begin: 0.15,
                    delay: Duration(milliseconds: 60 * index),
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showCreateTripDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('New Trip'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Trip name (e.g., Japan 2024)',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
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

                  final now = DateTime.now();
                  final trip = Trip(
                    id: const Uuid().v4(),
                    name: name,
                    startDate: now,
                    createdAt: now,
                    updatedAt: now,
                  );

                  await ref.read(tripRepositoryProvider).insert(trip);
                  ref.invalidate(tripsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  final Trip trip;
  final int index;

  const _TripCard({required this.trip, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;

    return GestureDetector(
      onTap: () => context.push('/trip/${trip.id}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 140,
          child: Row(
            children: [
              // Cover photo
              SizedBox(
                width: 120,
                child:
                    trip.coverPhotoPath != null
                        ? Image.file(
                          File(trip.coverPhotoPath!),
                          fit: BoxFit.cover,
                          height: double.infinity,
                          errorBuilder:
                              (_, __, ___) => _placeholderCover(colorScheme),
                        )
                        : _placeholderCover(colorScheme),
              ),

              // Trip info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(_dateRange, style: AppTextStyles.caption),
                      if (trip.description != null &&
                          trip.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            trip.description!,
                            style: AppTextStyles.body2.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          FutureBuilder<int>(
                            future: ref
                                .read(tripRepositoryProvider)
                                .getPhotoCount(trip.id),
                            builder: (context, snap) {
                              return Text(
                                '${snap.data ?? 0} photos',
                                style: AppTextStyles.caption,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Arrow
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderCover(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.luggage_outlined,
          size: 36,
          color: colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  String get _dateRange {
    final start = trip.startDate.formatted;
    if (trip.endDate != null) {
      return '$start - ${trip.endDate!.formatted}';
    }
    return start;
  }
}
