import 'package:flutter/material.dart';

/// Common text styles used across the app
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle headline1 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle headline2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle headline3 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle subtitle1 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle subtitle2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: Colors.grey,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle button = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}
