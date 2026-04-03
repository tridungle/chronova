import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/photo_import_service.dart';

/// Screen for importing photos with EXIF processing and progress feedback.
class PhotoImportScreen extends ConsumerStatefulWidget {
  const PhotoImportScreen({super.key});

  @override
  ConsumerState<PhotoImportScreen> createState() => _PhotoImportScreenState();
}

class _PhotoImportScreenState extends ConsumerState<PhotoImportScreen> {
  bool _isImporting = false;
  ImportResult? _result;
  String _statusMessage = '';
  int _currentProgress = 0;
  int _totalProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Photos')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            // Main illustration / status
            if (_result != null)
              _ImportResultView(result: _result!)
            else if (_isImporting)
              _ImportingView(
                current: _currentProgress,
                total: _totalProgress,
                message: _statusMessage,
              )
            else
              _ImportPrompt(onPickFromGallery: _pickFromGallery),

            const Spacer(),

            // Bottom actions
            if (_result != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Invalidate providers to reload data
                    ref.invalidate(allPhotosProvider);
                    ref.invalidate(timelineDaysProvider);
                    ref.invalidate(geoPhotosProvider);
                    ref.invalidate(photoCountProvider);
                    context.pop();
                  },
                  child: const Text('Done'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'Selecting photos...';
    });

    try {
      final importService = ref.read(photoImportServiceProvider);
      final result = await importService.pickAndImportPhotos(
        onProgress: (current, total) {
          setState(() {
            _currentProgress = current;
            _totalProgress = total;
            _statusMessage = 'Processing photo $current of $total...';
          });
        },
      );

      // Reverse geocode photos with GPS data
      if (result.withGps > 0) {
        setState(() => _statusMessage = 'Resolving locations...');
        final locationService = ref.read(locationServiceProvider);
        final photoRepo = ref.read(photoRepositoryProvider);

        for (final photo in result.photos) {
          if (photo.hasLocation) {
            try {
              final name = await locationService.getLocationName(
                photo.latitude!,
                photo.longitude!,
              );
              if (name != null) {
                await photoRepo.update(
                  photo.copyWith(locationName: name, updatedAt: DateTime.now()),
                );
              }
            } catch (_) {
              // Skip geocoding errors silently
            }
          }
        }
      }

      setState(() {
        _isImporting = false;
        _result = result;
      });
    } catch (e) {
      setState(() {
        _isImporting = false;
        _statusMessage = 'Error: $e';
      });
      if (mounted) {
        context.showSnackBar('Import failed: $e', isError: true);
      }
    }
  }
}

/// Prompt view when nothing is importing yet.
class _ImportPrompt extends StatelessWidget {
  final VoidCallback onPickFromGallery;

  const _ImportPrompt({required this.onPickFromGallery});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.photo_library_rounded,
                size: 56,
                color: colorScheme.primary,
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.8, 0.8)),
        const SizedBox(height: 24),
        Text(
          'Import Your Photos',
          style: AppTextStyles.headline2.copyWith(color: colorScheme.onSurface),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        const SizedBox(height: 12),
        Text(
          'We\'ll automatically extract dates, locations,\nand camera info from your photos.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body2.copyWith(color: Colors.grey),
        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
        const SizedBox(height: 32),

        // Gallery button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPickFromGallery,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Choose from Gallery'),
          ),
        ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

        const SizedBox(height: 16),

        // Info text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Photos are copied to app storage. Originals remain untouched.',
                  style: AppTextStyles.caption.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
      ],
    );
  }
}

/// Progress view while importing.
class _ImportingView extends StatelessWidget {
  final int current;
  final int total;
  final String message;

  const _ImportingView({
    required this.current,
    required this.total,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final progress = total > 0 ? current / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: total > 0 ? progress : null,
                  strokeWidth: 6,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              if (total > 0)
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Processing Photos', style: AppTextStyles.headline3),
        const SizedBox(height: 8),
        Text(
          message,
          style: AppTextStyles.body2.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        if (total > 0) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ],
    );
  }
}

/// Result view after import completes.
class _ImportResultView extends StatelessWidget {
  final ImportResult result;

  const _ImportResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final success = result.successCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                    success
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 44,
                color: success ? Colors.green : Colors.orange,
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          success ? 'Import Complete!' : 'No Photos Selected',
          style: AppTextStyles.headline2,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),

        if (success) ...[
          _ResultStat(
            icon: Icons.photo_rounded,
            label: 'Photos imported',
            value: '${result.successCount}',
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _ResultStat(
            icon: Icons.calendar_today_rounded,
            label: 'With date info',
            value: '${result.withExifDate}',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _ResultStat(
            icon: Icons.location_on_rounded,
            label: 'With GPS location',
            value: '${result.withGps}',
            color: Colors.green,
          ),
          if (result.failedCount > 0) ...[
            const SizedBox(height: 12),
            _ResultStat(
              icon: Icons.error_outline_rounded,
              label: 'Failed',
              value: '${result.failedCount}',
              color: Colors.red,
            ),
          ],
        ],
      ],
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _ResultStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.body2)),
          Text(
            value,
            style: AppTextStyles.subtitle1.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
