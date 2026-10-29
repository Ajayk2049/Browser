import 'package:flutter/material.dart';

class AppShapes {
  AppShapes._();

  /// Material 3 Expressive "cookie" shape — asymmetric rounded corners.
  static const cookie = RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(8),
      bottomRight: Radius.circular(24),
      bottomLeft: Radius.circular(8),
    ),
  );

  /// Material 3 Expressive "pill" shape.
  static final pill = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(999),
  );

  /// Material 3 Expressive "clover" approximation.
  static const clover = RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
      bottomRight: Radius.circular(8),
      bottomLeft: Radius.circular(8),
    ),
  );
}

