// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Chronova';
  static const String appTagline = 'Your Life, Beautifully Mapped';
  static const String appVersion = '1.0.0';
  static const String dbName = 'chronova.db';
  static const int dbVersion = 2;

  // Map tile URLs
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String cartoLightTileUrl =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const String cartoDarkTileUrl =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';

  // Animation durations
  static const Duration quickAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 350);
  static const Duration slowAnimation = Duration(milliseconds: 600);
  static const Duration heroAnimation = Duration(milliseconds: 800);

  // Photo thumbnail sizes
  static const int thumbnailSmall = 150;
  static const int thumbnailMedium = 400;
  static const int thumbnailLarge = 800;

  // Video export
  static const int videoFps = 30;
  static const int videoWidth = 1080;
  static const int videoHeight = 1920;
  static const double defaultAnimationSpeedSec = 3.0;

  // Mood options
  static const List<String> moods = [
    '😊',
    '😍',
    '🤩',
    '😌',
    '🥰',
    '😢',
    '😤',
    '🤔',
    '😴',
    '🥳',
    '✈️',
    '🏔️',
    '🏖️',
    '🌆',
    '🍽️',
  ];

  // Default tags
  static const List<String> defaultTags = [
    'Travel',
    'Food',
    'Nature',
    'City',
    'Beach',
    'Mountain',
    'Family',
    'Friends',
    'Work',
    'Adventure',
    'Culture',
    'Sunset',
    'Night',
    'Sport',
    'Art',
  ];
}
