import 'package:flutter/animation.dart';

class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);

  static const easeOut = Cubic(0.22, 1, 0.36, 1);
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);

  /// Material 3 Expressive spring — used for interactive feedback.
  static const spring = Cubic(0.34, 1.56, 0.64, 1);
}

