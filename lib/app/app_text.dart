import 'package:flutter/material.dart';

abstract final class AppText {
  static const micro12 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const label14 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.14,
  );

  static const body16 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.16,
  );

  static const heading20 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.4,
  );

  static const title24 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.48,
  );

  static const display36 = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1.44,
  );

  static const amount56 = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -2.24,
  );
}