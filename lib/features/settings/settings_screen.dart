import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/photo_import_service.dart';

/// App settings screen with theme toggle and other options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Shows a dialog to re-scan EXIF data for all photos.
  void _showRescanDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _RescanExifDialog(ref: ref);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App info header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chronova',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Life, Beautifully Mapped',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v${AppConstants.appVersion}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Theme section
          Text(
            'Appearance',
            style: AppTextStyles.label.copyWith(
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.brightness_auto_rounded,
                  title: 'System',
                  isSelected: themeMode == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).state = 0;
                  },
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.light_mode_rounded,
                  title: 'Light',
                  isSelected: themeMode == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).state = 1;
                  },
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark',
                  isSelected: themeMode == 2,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).state = 2;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Stats section
          Text(
            'Statistics',
            style: AppTextStyles.label.copyWith(
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer(
                builder: (context, ref, _) {
                  final photoCount = ref.watch(photoCountProvider);
                  final tripCount = ref.watch(tripsProvider);

                  return Row(
                    children: [
                      _StatItem(
                        icon: Icons.photo_library_rounded,
                        label: 'Photos',
                        value: photoCount.when(
                          data: (c) => '$c',
                          loading: () => '...',
                          error: (_, __) => '0',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                      _StatItem(
                        icon: Icons.luggage_rounded,
                        label: 'Trips',
                        value: tripCount.when(
                          data: (t) => '${t.length}',
                          loading: () => '...',
                          error: (_, __) => '0',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Data management section
          Text(
            'Data Management',
            style: AppTextStyles.label.copyWith(
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Re-scan EXIF Data'),
                  subtitle: const Text('Re-read metadata from all photo files'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showRescanDialog(context, ref);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About section
          Text(
            'About',
            style: AppTextStyles.label.copyWith(
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Version'),
                  trailing: const Text(AppConstants.appVersion),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Built with Flutter'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: AppConstants.appVersion,
                      applicationIcon: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.timeline_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      children: [
                        const Text(
                          'A personal photo timeline and journey app that reads '
                          'EXIF data from your photos, creates a beautiful '
                          'timeline with journal notes, and maps your travels.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : Colors.grey[500],
      ),
      title: Text(
        title,
        style: AppTextStyles.body1.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? colorScheme.primary : null,
        ),
      ),
      trailing:
          isSelected
              ? Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 22,
              )
              : null,
      onTap: onTap,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: context.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headline3.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Dialog that re-scans EXIF data from all photo files and updates the DB.
class _RescanExifDialog extends StatefulWidget {
  final WidgetRef ref;

  const _RescanExifDialog({required this.ref});

  @override
  State<_RescanExifDialog> createState() => _RescanExifDialogState();
}

class _RescanExifDialogState extends State<_RescanExifDialog> {
  bool _isRunning = false;
  bool _isDone = false;
  int _current = 0;
  int _total = 0;
  int _updated = 0;
  int _skipped = 0;
  int _errors = 0;
  String _statusText = '';

  Future<void> _runRescan() async {
    setState(() {
      _isRunning = true;
      _statusText = 'Loading photos...';
    });

    final photoRepo = widget.ref.read(photoRepositoryProvider);
    final exifService = widget.ref.read(exifServiceProvider);
    final allPhotos = await photoRepo.getAll();

    setState(() {
      _total = allPhotos.length;
      _statusText = 'Scanning 0 / $_total...';
    });

    for (int i = 0; i < allPhotos.length; i++) {
      if (!mounted) return;

      final photo = allPhotos[i];
      setState(() {
        _current = i + 1;
        _statusText = 'Scanning $_current / $_total...';
      });

      try {
        // Check if file still exists
        final file = File(photo.filePath);
        if (!await file.exists()) {
          _skipped++;
          continue;
        }

        final exif = await exifService.extractFromFile(photo.filePath);

        // Only update if EXIF had useful data
        if (exif.hasDate || exif.hasLocation || exif.cameraModel != null) {
          await photoRepo.updateExifFields(
            photo.id,
            dateTaken: exif.dateTaken,
            latitude: exif.latitude,
            longitude: exif.longitude,
            altitude: exif.altitude,
            cameraModel: exif.cameraModel,
            width: exif.width,
            height: exif.height,
          );
          _updated++;
        } else {
          _skipped++;
        }

        // Backfill file_hash if missing (for photos imported before
        // duplicate detection was added)
        if (photo.fileHash == null) {
          try {
            final hash = await PhotoImportService.computeFileHash(file);
            await photoRepo.updateFileHash(photo.id, hash);
          } catch (_) {
            // Non-critical — skip hash backfill errors silently
          }
        }
      } catch (e) {
        _errors++;
      }
    }

    if (!mounted) return;

    // Invalidate providers so UI refreshes with new data
    widget.ref.invalidate(allPhotosProvider);
    widget.ref.invalidate(geoPhotosProvider);
    widget.ref.invalidate(timelineDaysProvider);
    widget.ref.invalidate(photoCountProvider);

    setState(() {
      _isRunning = false;
      _isDone = true;
      _statusText =
          'Done! Updated $_updated, '
          'skipped $_skipped, '
          'errors $_errors.';
    });

    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isDone ? Icons.check_circle_rounded : Icons.refresh_rounded,
            color: _isDone ? Colors.green : colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(_isDone ? 'Scan Complete' : 'Re-scan EXIF Data'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isRunning && !_isDone)
            const Text(
              'This will re-read EXIF metadata (date, GPS, camera) from all '
              'photo files and update the database.\n\n'
              'This is useful if photos were imported before a bug fix '
              'that affected EXIF parsing.',
            ),
          if (_isRunning || _isDone) ...[
            if (_isRunning && _total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _current / _total : null,
                  minHeight: 8,
                ),
              ),
            if (_isRunning && _total == 0)
              const LinearProgressIndicator(minHeight: 8),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: AppTextStyles.body2.copyWith(color: Colors.grey[600]),
            ),
            if (_isDone) ...[
              const SizedBox(height: 12),
              _RescanStat(
                icon: Icons.update_rounded,
                label: 'Updated',
                value: _updated,
                color: Colors.green,
              ),
              const SizedBox(height: 4),
              _RescanStat(
                icon: Icons.skip_next_rounded,
                label: 'Skipped (no new data)',
                value: _skipped,
                color: Colors.orange,
              ),
              if (_errors > 0) ...[
                const SizedBox(height: 4),
                _RescanStat(
                  icon: Icons.error_outline_rounded,
                  label: 'Errors',
                  value: _errors,
                  color: Colors.red,
                ),
              ],
            ],
          ],
        ],
      ),
      actions: [
        if (!_isRunning && !_isDone)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        if (!_isRunning && !_isDone)
          FilledButton.icon(
            onPressed: _runRescan,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Start Scan'),
          ),
        if (_isDone)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
      ],
    );
  }
}

class _RescanStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _RescanStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: AppTextStyles.caption)),
      ],
    );
  }
}
