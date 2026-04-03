import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Load persisted preferences
  final prefs = await SharedPreferences.getInstance();
  final savedThemeMode = prefs.getInt('theme_mode') ?? 0;
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(
    ProviderScope(
      overrides: [
        // Seed the theme provider with the persisted value
        themeModeProvider.overrideWith((ref) => savedThemeMode),
      ],
      child: ChronovaApp(showOnboarding: !onboardingComplete),
    ),
  );
}

/// Root app widget with theme, routing, and onboarding.
class ChronovaApp extends ConsumerWidget {
  final bool showOnboarding;

  const ChronovaApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Persist theme mode whenever it changes
    ref.listen<int>(themeModeProvider, (_, next) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', next);
    });

    return MaterialApp.router(
      title: 'Chronova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _resolveThemeMode(themeMode),
      routerConfig: appRouter,
      builder: (context, child) {
        if (showOnboarding) {
          return _OnboardingGate(child: child!);
        }
        return child!;
      },
    );
  }

  ThemeMode _resolveThemeMode(int mode) {
    switch (mode) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// Shows onboarding on first launch, then transitions to the main app.
class _OnboardingGate extends StatefulWidget {
  final Widget child;

  const _OnboardingGate({required this.child});

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool _onboardingDone = false;

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone) return widget.child;

    return OnboardingScreen(
      onComplete: () => setState(() => _onboardingDone = true),
    );
  }
}
