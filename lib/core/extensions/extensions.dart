import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  /// "Jan 15, 2024"
  String get formatted => DateFormat.yMMMd().format(this);

  /// "January 15, 2024"
  String get formattedLong => DateFormat.yMMMMd().format(this);

  /// "3:45 PM"
  String get formattedTime => DateFormat.jm().format(this);

  /// "Jan 15, 2024 at 3:45 PM"
  String get formattedFull =>
      '${DateFormat.yMMMd().format(this)} at ${DateFormat.jm().format(this)}';

  /// "Today", "Yesterday", or "Jan 15, 2024"
  String get relative {
    final now = DateTime.now();
    final diff = now.difference(this);
    if (diff.inDays == 0 && now.day == day) return 'Today';
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != day)) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) return DateFormat.EEEE().format(this);
    return formatted;
  }

  /// Same calendar day check
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Group key "2024-01-15"
  String get dateKey => DateFormat('yyyy-MM-dd').format(this);
}

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Use specific MediaQuery.xxxOf(context) methods to avoid unnecessary
  /// rebuilds. These only trigger rebuilds when the specific property changes,
  /// unlike MediaQuery.of(context) which rebuilds on any MediaQuery change.
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);
  bool get isDark => theme.brightness == Brightness.dark;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? colorScheme.error : null,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

extension StringX on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String truncate(int maxLength) =>
      length <= maxLength ? this : '${substring(0, maxLength)}...';
}

extension ListX<T> on List<T> {
  List<List<T>> chunk(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }
    return chunks;
  }
}
