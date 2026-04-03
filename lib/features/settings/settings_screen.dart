import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/extensions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text_styles.dart';

/// App settings screen with theme toggle and other options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
                  'v1.0.0',
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
                  onTap: () => ref.read(themeModeProvider.notifier).state = 0,
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.light_mode_rounded,
                  title: 'Light',
                  isSelected: themeMode == 1,
                  onTap: () => ref.read(themeModeProvider.notifier).state = 1,
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark',
                  isSelected: themeMode == 2,
                  onTap: () => ref.read(themeModeProvider.notifier).state = 2,
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
                  trailing: const Text('1.0.0'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Built with Flutter'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {},
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
